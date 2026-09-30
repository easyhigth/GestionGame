class_name VillageNeeds
extends Node
## Besoins des habitants : nourriture (réserve du village), lit et bonheur.
## - La réserve se remplit avec la boulangerie, la grange et ce que le héros y dépose (panneau du royaume, U).
##   Chaque habitant y prend un repas quand il a faim.
## - Lits : ceux des maisons et dortoirs, plus 2 par cabane du village encore debout.
## - Bonheur : nourriture, lit, taverne, temple, marché, bibliothèque, sécurité (raids), rang du royaume.
##   Heureux : travaille plus vite, attire des voyageurs. Malheureux trop longtemps : quitte le village.

signal changed
signal deposited(points: float)
## Un habitant est parti (nom).
signal villager_left(name: String)

## Un repas pris dans la réserve (points de nourriture, comme la faim du héros).
const MEAL := 60.0
## Faim d'un habitant : de 100 à 0 en 20 minutes ; il mange sous 40.
const FOOD_DRAIN := 100.0 / 1200.0
const EAT_BELOW := 40.0
## Réserve au début d'une partie.
const START_STOCK := 300.0
## Lits offerts par chaque cabane du village de départ.
const HUT_BEDS := 2
## Bonus de bonheur des pièces (un seul par type).
const AMENITIES := {"taverne": 10.0, "temple": 10.0, "marche": 5.0, "bibliotheque": 5.0, "salle_trone": 5.0}
## Temps malheureux avant de prévenir, puis de partir (secondes).
const WARN_AFTER := 120.0
const LEAVE_AFTER := 240.0
## Délai entre deux arrivées de voyageurs attirés par un village heureux.
const ARRIVAL_EVERY := 180.0

var food_stock := START_STOCK
var _tick := 0.0
var _safety := 0.0
var _safety_left := 0.0
var _arrival := ARRIVAL_EVERY


func _ready() -> void:
	add_to_group("village_needs")
	var rm := get_tree().get_first_node_in_group("raids")
	if rm and rm.has_signal("raid_ended"):
		rm.raid_ended.connect(func(_r, repelled: bool, _t):
			_safety = 10.0 if repelled else -15.0
			_safety_left = 600.0 if repelled else 300.0)
	if not SaveGame.village_state.is_empty():
		import_state(SaveGame.village_state)
		SaveGame.village_state = {}


## Habitants concernés : ceux du village (pas les voyageurs ni les compagnons partis en expédition).
func members() -> Array:
	return get_tree().get_nodes_in_group("villagers").filter(func(v): return not v.companion)


## Places pour dormir : [[position, sorte], ...] — les lits des maisons et dortoirs (sur le meuble « lit »),
## puis 2 places par cabane du village (devant sa porte : on dort à l'intérieur).
func bed_spots() -> Array:
	var out := []
	var k := get_tree().get_first_node_in_group("kingdom") as Kingdom
	var world := get_tree().get_first_node_in_group("world") as WorldGenerator
	if world == null:
		return out
	if k:
		for r in k.typed_rooms():
			var n: int = (r.type as RoomTypeData).beds
			if n <= 0:
				continue
			var lits := []
			for c in r.cells:
				for f in world.build.furniture_in(c):
					if (f.item as ItemData).id == "lit" and absf(float(f.base) - float(r.floor)) < 1.3:
						lits.append(Vector3(c.x + 0.5, float(f.base) + 0.55, c.y + 0.5))
			for i in n:
				if lits.is_empty():
					var cell: Vector2i = r.cells.keys()[i % r.cells.size()]
					out.append([Vector3(cell.x + 0.5, float(r.floor), cell.y + 0.5), "lit"])
				else:
					var p: Vector3 = lits[i % lits.size()]
					out.append([p + Vector3(0.22 * (i / lits.size()), 0, 0), "lit"])
	var center := world.cell_center(world.spawn_cell)
	for id in ["hut_1", "hut_2", "hut_3"]:
		var hut := world.village_prop(id)
		if hut == null:
			continue
		var door: Vector3 = hut.global_position + (center - hut.global_position).normalized() * 2.4
		door.y = world.ground_height_at(door + Vector3(0, 3, 0))
		for i in HUT_BEDS:
			out.append([door, "cabane"])
	return out


func total_beds() -> int:
	var n := 0
	var k := get_tree().get_first_node_in_group("kingdom") as Kingdom
	if k:
		n += k.beds()
	var world := get_tree().get_first_node_in_group("world") as WorldGenerator
	if world:
		for id in ["hut_1", "hut_2", "hut_3"]:
			if world.village_prop(id) != null:
				n += HUT_BEDS
	return n


func add_food(points: float) -> void:
	food_stock += points
	changed.emit()


## Dépose toute la nourriture du sac du héros dans la réserve. Renvoie les points ajoutés.
func deposit_from(p: Player) -> float:
	var total := 0.0
	for e in p.inventory.entries.duplicate():
		var it := e.item as ItemData
		if it and it.is_food():
			var n: int = e.count
			if p.inventory.remove(it, n):
				total += it.food * n
	if total > 0.0:
		add_food(total)
		deposited.emit(total)
		Sound.ui("craft")
	return total


## Nombre de repas en réserve.
func meals() -> int:
	return floori(food_stock / MEAL)


func average_happiness() -> float:
	var m := members()
	if m.is_empty():
		return 0.0
	var s := 0.0
	for v in m:
		s += float(v.happiness)
	return s / m.size()


static func mood_name(h: float) -> String:
	if h >= 70.0:
		return "Heureux"
	if h >= 40.0:
		return "Content"
	if h >= 20.0:
		return "Mécontent"
	return "Malheureux"


static func mood_color(h: float) -> Color:
	if h >= 70.0:
		return Color("8ad66a")
	if h >= 40.0:
		return Color("e8d890")
	if h >= 20.0:
		return Color("f0a050")
	return Color("e0605a")


static func work_mult_for(h: float) -> float:
	if h >= 70.0:
		return 1.25
	if h >= 40.0:
		return 1.0
	if h >= 20.0:
		return 0.8
	return 0.6


func _process(delta: float) -> void:
	_tick += delta
	if _tick < 1.0:
		return
	var dt := _tick
	_tick = 0.0
	_update(dt)


func _update(dt: float) -> void:
	var list := members()
	# ordre stable (deux habitants peuvent porter le même nom) : sinon les lits s'échangeraient sans cesse
	list.sort_custom(func(a, b): return a.villager_name < b.villager_name or (a.villager_name == b.villager_name and a.get_instance_id() < b.get_instance_id()))
	var spots := bed_spots()
	var beds := spots.size()
	var k := get_tree().get_first_node_in_group("kingdom") as Kingdom
	# confort des pièces du royaume
	var comfort := 0.0
	var seen := {}
	if k:
		for r in k.rooms:
			if r.type and not seen.has(r.type.id):
				seen[r.type.id] = true
				comfort += float(AMENITIES.get((r.type as RoomTypeData).id, 0.0))
		comfort += k.rank * 2.0
	# le royaume éveillé (fin de l'histoire) : tout le monde est plus heureux
	var st := get_tree().get_first_node_in_group("story")
	if st and st.is_done():
		comfort += 10.0
	# jour de fête
	var se := get_tree().get_first_node_in_group("seasons")
	if se and se.is_festival():
		comfort += 12.0
	if _safety_left > 0.0:
		_safety_left -= dt
		if _safety_left <= 0.0:
			_safety = 0.0
	var p := get_tree().get_first_node_in_group("player") as Player
	var we := get_tree().get_first_node_in_group("weather") as Weather
	var wet := we != null and we.is_wet()
	for i in list.size():
		var v = list[i]
		# repas
		v.food = maxf(0.0, float(v.food) - FOOD_DRAIN * dt)
		if v.food < EAT_BELOW and food_stock >= MEAL * 0.5:
			var eat := minf(MEAL, food_stock)
			food_stock -= eat
			v.food = minf(100.0, v.food + eat)
		v.has_bed = i < beds
		var spot: Vector3 = spots[i][0] if v.has_bed else Vector3.INF
		var kind: String = spots[i][1] if v.has_bed else ""
		if spot != v.bed_spot or kind != v.bed_kind:
			v.bed_spot = spot
			v.bed_kind = kind
			# le lit a changé pendant la nuit : il y retourne
			if v.activity == "sommeil" and not v.is_sleeping():
				v._start_activity("sommeil")
		# bonheur visé et raisons
		# nourri et logé : content ; il faut un peu de confort (taverne, temple...) pour être heureux
		var target := 42.0 + comfort + _safety
		var reasons := []
		if v.food >= EAT_BELOW:
			target += 15.0
		elif v.food >= 15.0:
			target -= 10.0
			reasons.append("a faim")
		else:
			target -= 40.0
			reasons.append("meurt de faim")
		if v.has_bed:
			# un vrai lit dans une maison vaut mieux qu'une place dans une cabane
			target += 15.0 if v.bed_kind == "lit" else 10.0
		else:
			target -= 20.0
			reasons.append("pas de lit")
		if _safety < 0.0:
			reasons.append("a eu peur du raid")
		# sous la pluie sans abri
		if wet and not v.is_sheltered():
			target -= 6.0
			reasons.append("trempé")
		# les quêtes réussies pour lui le rendent plus heureux (jusqu'à +15 quand il est ton ami)
		target += 5.0 * mini(int(v.friendship), 3)
		target = clampf(target, 0.0, 100.0)
		v.happiness = move_toward(float(v.happiness), target, 0.5 * dt)
		v.mood_reasons = reasons
		v.work_mult = work_mult_for(v.happiness)
		# trop malheureux trop longtemps : il s'en va
		if v.happiness < 20.0:
			v.unhappy_time += dt
			if v.unhappy_time >= WARN_AFTER and v.unhappy_time - dt < WARN_AFTER and p:
				p.notify.emit("%s est malheureux (%s) et pense à quitter le village." % [v.villager_name, ", ".join(PackedStringArray(reasons)) if not reasons.is_empty() else "rien ne va"])
			if v.unhappy_time >= LEAVE_AFTER:
				_leave(v, p)
		else:
			v.unhappy_time = maxf(0.0, v.unhappy_time - dt * 2.0)
	_arrivals(dt, list, p)
	changed.emit()


func _leave(v: Node, p: Player) -> void:
	var name: String = v.villager_name
	var k := get_tree().get_first_node_in_group("kingdom") as Kingdom
	if k:
		k.assign(v, null)
	VoxelBurst.spawn(v.get_parent(), (v as Node3D).global_position + Vector3(0, 1, 0), Color(0.7, 0.7, 0.8), 16, 2.5, 0.1, 0.6, "up", 4.0, false)
	v.queue_free()
	if p:
		p.notify.emit("%s a quitté le village : il était trop malheureux." % name)
	villager_left.emit(name)


## Un village heureux attire des voyageurs : l'un d'eux arrive près du village de temps en temps.
func _arrivals(dt: float, list: Array, p: Player) -> void:
	_arrival -= dt
	if _arrival > 0.0:
		return
	_arrival = ARRIVAL_EVERY
	var k := get_tree().get_first_node_in_group("kingdom") as Kingdom
	var world := get_tree().get_first_node_in_group("world") as WorldGenerator
	if world == null or world.villager_scene == null or list.is_empty() or average_happiness() < 65.0:
		return
	if k and list.size() >= k.population_cap():
		return
	# un seul visiteur à la fois près du village
	for s in get_tree().get_nodes_in_group("strangers"):
		if s.has_meta("attracted"):
			return
	var v := world.villager_scene.instantiate() as Villager
	v.stranger = true
	v.race = world.villager_races[randi() % world.villager_races.size()] if not world.villager_races.is_empty() else null
	v.villager_name = Villager.NAMES[randi() % Villager.NAMES.size()]
	v.level = randi_range(1, 3)
	var jobs := Villager.JOBS.duplicate()
	jobs.shuffle()
	v.talents = {jobs[0]: randf_range(0.45, 0.7), jobs[1]: randf_range(0.15, 0.3)}
	v.recruit_offer = world.make_offer(jobs[0], v.level)
	v.set_meta("attracted", true)
	v.wander_radius = 2.0
	world.get_node("Village").add_child(v)
	var a := randf() * TAU
	var pos := world.cell_center(world.spawn_cell) + Vector3(cos(a), 0, sin(a)) * 11.0
	pos.y = world.ground_height_at(pos + Vector3(0, 3, 0))
	v.global_position = pos
	v.home = pos
	if p:
		p.notify.emit("Attiré par ton village heureux, un voyageur arrive (%s) : parle-lui (E) pour qu'il s'installe." % v.villager_name)


# ---------------------------------------------------------------- sauvegarde

func export_state() -> Dictionary:
	return {"stock": food_stock, "safety": _safety, "safety_left": _safety_left, "arrival": _arrival}


func import_state(d: Dictionary) -> void:
	food_stock = float(d.get("stock", START_STOCK))
	_safety = float(d.get("safety", 0.0))
	_safety_left = float(d.get("safety_left", 0.0))
	_arrival = float(d.get("arrival", ARRIVAL_EVERY))
	changed.emit()
