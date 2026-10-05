class_name Mounts
extends Node
## Montures et bateaux : chevaux sauvages dans les prés (on les apprivoise avec des carottes, E pour
## monter et descendre), barques posées sur l'eau (V face à l'eau avec une barque en main, E pour monter,
## E près d'une berge pour débarquer), et îles au trésor au large (un coffre sur chacune).

signal tamed(horse: Horse)
signal boarded(what: String)
signal island_chest_opened(id: String)

const MAX_WILD := 3
const SPAWN_MIN := 30.0
const SPAWN_MAX := 50.0
const DESPAWN := 100.0
const WILD := {"prairie": 3, "foret": 1, "montagnes": 1}
## Vitesse en barque (multiplicateur de la marche) et hauteur du héros assis.
const BOAT_SPEED := 1.5
const BOAT_SEAT := 0.35
## Le voilier va deux fois plus vite que la barque.
const SAIL_SPEED := 3.2
const SAIL_SEAT := 0.5
## En griffon : la selle, et la vitesse en vol (multipliée par celle du vol).
const GRIFFON_SEAT := 1.78
const GRIFFON_SPEED := 1.6
const BOAT_MODEL := preload("res://scenes/decor/boat.tscn")
const CHEST_MODEL := preload("res://assets/furniture/coffre.glb")

var world: WorldGenerator
var player: Player
## Ce que monte le héros : un cheval, une barque, ou null.
var mount: Node3D
var boats: Array = []
## Le griffon (s'il a été appelé), et le sifflet déjà offert aux parties d'avant le sifflet.
var griffon: Node3D
var whistle_given := false
var _t := 0.0
## Coffres des îles déjà ouverts (identifiant de l'île -> vrai).
var opened := {}
var _island_nodes := {}
var _tick := 0.0
var _spawn_tick := 3.0


func _ready() -> void:
	add_to_group("mounts")
	if not SaveGame.mounts_state.is_empty():
		import_state.call_deferred(SaveGame.mounts_state)
		SaveGame.mounts_state = {}


func horses() -> Array:
	return get_tree().get_nodes_in_group("horses").filter(func(h): return is_instance_valid(h) and not h.is_queued_for_deletion())


func is_riding() -> bool:
	return mount != null and is_instance_valid(mount) and (mount is Horse or mount is Enemy)


func is_sailing() -> bool:
	return mount != null and is_instance_valid(mount) and not (mount is Horse or mount is Enemy) and mount != griffon


func is_flying() -> bool:
	return mount != null and is_instance_valid(mount) and mount == griffon


# ---------------------------------------------------------------- E

## E : descendre, monter, donner une carotte, embarquer. Vrai si quelque chose a été fait.
func try_interact(p: Player) -> bool:
	player = p
	if mount != null and is_instance_valid(mount):
		return dismount()
	if p.global_position.y < WorldGenerator.UNDERGROUND:
		return false
	if griffon and is_instance_valid(griffon) and griffon.global_position.distance_to(p.global_position) < 3.2:
		mount_griffon()
		return true
	# une barque tout près (depuis la berge ou en nageant)
	for b in boats:
		if is_instance_valid(b) and Vector2(b.global_position.x - p.global_position.x, b.global_position.z - p.global_position.z).length() < 2.6:
			board(b)
			return true
	# un familier que l'on peut monter (loup, sanglier, ours...)
	var fam := get_tree().get_first_node_in_group("familiars_mgr")
	if fam:
		for entry in fam.team():
			var n = entry.node
			if n and is_instance_valid(n) and n.is_alive() and fam.rideable(entry) and n.global_position.distance_to(p.global_position) < 2.6:
				ride_familiar(n)
				return true
	for h in horses():
		if h.global_position.distance_to(p.global_position) > 2.4:
			continue
		if h.tamed:
			ride(h)
			return true
		if h.following:
			var carrot := Items.get_item("carotte")
			if p.inventory.count(carrot) <= 0:
				p.notify.emit("Il te faut des carottes.")
				return true
			p.inventory.remove(carrot, 1)
			Sound.play("eat", h.global_position)
			if h.feed():
				p.feat.emit("Cheval apprivoisé !", Color("ffe08a"))
				p.notify.emit("Le cheval porte maintenant une selle : {interact} pour monter, {interact} pour descendre.")
				tamed.emit(h)
			else:
				p.notify.emit("Le cheval mange la carotte (%d / %d)." % [h.trust, Horse.TAME_CARROTS])
			return true
	# un coffre d'île
	for id in _island_nodes:
		var n: Node3D = _island_nodes[id]
		if is_instance_valid(n) and not opened.has(id) and n.global_position.distance_to(p.global_position) < 2.4:
			_open_island_chest(id, n)
			return true
	return false


func ride(h: Horse) -> void:
	mount = h
	h.ridden = true
	h.following = false
	player.global_position = h.global_position
	player.visual.position.y = Horse.SADDLE_Y
	Sound.play("step_grass", h.global_position)
	boarded.emit("cheval")


## Monter sur un familier : il court sous le héros et attaque ce qu'il percute.
func ride_familiar(e: Enemy) -> void:
	mount = e
	e.set_meta("ridden", true)
	e.set("_target", null)
	player.global_position = e.global_position
	player.visual.position.y = 0.95 * e.visual.scale.y
	Sound.play("step_grass", e.global_position)
	player.notify.emit("Tu montes %s : {interact} pour descendre." % e.familiar_name)
	boarded.emit("familier")


func board(b: Node3D) -> void:
	mount = b
	player.global_position = Vector3(b.global_position.x, world.water_surface, b.global_position.z)
	var sail: bool = b.get_meta("kind", "barque") == "voilier"
	player.visual.position.y = SAIL_SEAT if sail else BOAT_SEAT
	player.swimming = false
	Sound.play("door", b.global_position)
	boarded.emit(b.get_meta("kind", "barque"))
	if sail:
		player.notify.emit("Cap sur le large ! Le voilier file deux fois plus vite que la barque. {interact} près d'une berge pour débarquer.")


# ---------------------------------------------------------------- griffon

## Le sifflet : le griffon se pose devant le héros. Renvoie « » si c'est fait, sinon pourquoi pas.
func call_griffon(p: Player) -> String:
	player = p
	if p.global_position.y < WorldGenerator.UNDERGROUND:
		return "Le griffon ne peut pas te rejoindre sous terre."
	if is_flying():
		return "Tu voles déjà sur le griffon."
	if mount != null and is_instance_valid(mount):
		return "Descends d'abord de ta monture."
	var fwd := Vector3(p.facing.x, 0, p.facing.z).normalized()
	if fwd.length() < 0.1:
		fwd = Vector3.FORWARD
	var at := p.global_position + fwd * 3.0
	at.y = world.support_height(at, world.terrain_height(world.cell_at(at)) + 0.3)
	if griffon == null or not is_instance_valid(griffon):
		griffon = _make_griffon()
	griffon.global_position = at
	griffon.rotation.y = atan2(-fwd.x, -fwd.z)
	VoxelBurst.spawn(world, at + Vector3(0, 1.5, 0), Color("f2ead8"), 26, 4.0, 0.1, 0.8, "up", 3.0, false)
	Sound.ui("talent")
	p.notify.emit("Le griffon se pose dans un grand battement d'ailes. {interact} pour monter.")
	return ""


func _make_griffon() -> Node3D:
	var g := ExploreModels.griffon()
	world.add_child(g)
	var lab := Label3D.new()
	lab.text = "Griffon\nF : monter"
	lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lab.font_size = 30
	lab.pixel_size = 0.007
	lab.outline_size = 8
	lab.modulate = Color("f2ead8")
	lab.position.y = 3.2
	g.add_child(lab)
	g.set_meta("label", lab)
	return g


func mount_griffon() -> void:
	mount = griffon
	player.global_position = griffon.global_position
	player.visual.position.y = GRIFFON_SEAT
	player.swimming = false
	(griffon.get_meta("label") as Label3D).visible = false
	Sound.ui("talent")
	player.notify.emit("En selle ! {jump} : monter, {dig} : descendre, {interact} : se poser.")
	boarded.emit("griffon")


## Se poser : le griffon descend jusqu'au sol (ou sur les blocs), le héros met pied à terre.
func _land_griffon() -> void:
	var at := player.global_position
	var ground := world.support_height(at, world.terrain_height(world.cell_at(at)) + 0.3)
	var t := world.terrain_type(world.cell_at(at))
	if (t == WorldGenerator.WATER or t == WorldGenerator.DEEP) and ground < world.water_surface + 0.2:
		player.notify.emit("Pas ici : le griffon ne se pose pas sur l'eau.")
		return
	mount = null
	player.visual.position.y = 0.0
	griffon.global_position = Vector3(at.x, ground, at.z)
	(griffon.get_meta("label") as Label3D).visible = true
	var side := Vector3(player.facing.z, 0, -player.facing.x).normalized() * 1.6
	var foot := Vector3(at.x, ground, at.z) + side
	foot.y = world.support_height(foot, world.terrain_height(world.cell_at(foot)) + 0.3)
	player.global_position = foot
	player.airborne = true
	player.air_vy = 0.0


## Descendre du cheval, ou débarquer sur la berge la plus proche. Vrai si fait.
func dismount() -> bool:
	if is_flying():
		_land_griffon()
		return true
	if mount is Enemy:
		var e := mount as Enemy
		e.remove_meta("ridden")
		mount = null
		player.visual.position.y = 0.0
		var side := Vector3(player.facing.z, 0, -player.facing.x).normalized() * 1.2
		player.global_position = world.constrain_move(player.global_position, player.global_position + side)
		return true
	if mount is Horse:
		var h := mount as Horse
		h.ridden = false
		h.home = h.global_position
		mount = null
		player.visual.position.y = 0.0
		var side := Vector3(player.facing.z, 0, -player.facing.x).normalized() * 1.1
		player.global_position = world.constrain_move(player.global_position, player.global_position + side)
		return true
	# barque : on cherche une berge tout près
	var here := player.global_position
	var best := Vector3.INF
	var bd := INF
	for dz in range(-2, 3):
		for dx in range(-2, 3):
			var c := world.cell_at(here) + Vector2i(dx, dz)
			var t := world.terrain_type(c)
			if t == WorldGenerator.WATER or t == WorldGenerator.DEEP:
				continue
			var p := world.cell_center(c)
			if p.y - world.water_surface > 1.2 or not world.build.column(c).is_empty():
				continue
			var d := p.distance_to(here)
			if d < bd:
				bd = d
				best = p
	if best == Vector3.INF:
		player.notify.emit("Approche-toi d'une berge pour débarquer.")
		return true
	mount = null
	player.visual.position.y = 0.0
	player.global_position = best
	return true


# ---------------------------------------------------------------- chaque image

## Déplacement du héros en barque : seulement sur l'eau. Renvoie vrai s'il a été géré.
func sail_move(delta: float) -> bool:
	if not is_sailing():
		return false
	var from := player.global_position
	var sail: bool = mount.get_meta("kind", "barque") == "voilier"
	var spd := SAIL_SPEED if sail else BOAT_SPEED
	var to := from + Vector3(player.velocity.x, 0, player.velocity.z) * spd * delta
	var ok := func(p: Vector3) -> bool:
		var c := world.cell_at(p)
		var t := world.terrain_type(c)
		return (t == WorldGenerator.WATER or t == WorldGenerator.DEEP) and world.build.column(c).is_empty()
	if not ok.call(to):
		to = Vector3(to.x, to.y, from.z)
		if not ok.call(to):
			to = Vector3(from.x, to.y, player.global_position.z + player.velocity.z * spd * delta)
			if not ok.call(to):
				to = from
	to.y = world.water_surface + sin(Time.get_ticks_msec() * 0.002) * 0.04
	player.global_position = to
	mount.global_position = to - Vector3(0, 0.05, 0)
	var f := Vector3(player.facing.x, 0, player.facing.z)
	if f.length() > 0.1:
		mount.rotation.y = lerp_angle(mount.rotation.y, atan2(f.x, f.z), clampf(delta * (3.0 if sail else 5.0), 0.0, 1.0))
	if sail:
		# la voile se gonfle quand on avance, et le bateau tangue
		var v := mount.get_node_or_null("Modele/Voile") as Node3D
		var moving := Vector2(player.velocity.x, player.velocity.z).length() > 0.1
		if v:
			v.scale.z = lerpf(v.scale.z, 2.2 if moving else 1.0, clampf(delta * 2.0, 0.0, 1.0))
		mount.rotation.z = sin(Time.get_ticks_msec() * 0.0012) * 0.035
	return true


func _process(delta: float) -> void:
	if world == null:
		return
	if player == null:
		player = get_tree().get_first_node_in_group("player") as Player
		return
	if is_riding():
		var m := mount
		m.global_position = player.global_position
		m.set("facing", player.facing)
		m.get("visual").animate(delta, Vector3(player.velocity.x, 0, player.velocity.z), player.facing)
		var dead: bool = m is Enemy and not (m as Enemy).is_alive()
		if not player.is_alive() or player.global_position.y < WorldGenerator.UNDERGROUND or dead:
			dismount()
	elif is_sailing() and (not player.is_alive() or player.global_position.y < WorldGenerator.UNDERGROUND):
		mount = null
		player.visual.position.y = 0.0
	_t += delta
	if is_flying():
		griffon.global_position = player.global_position
		var f := Vector3(player.facing.x, 0, player.facing.z)
		if f.length() > 0.1:
			griffon.rotation.y = lerp_angle(griffon.rotation.y, atan2(f.x, f.z), clampf(delta * 6.0, 0.0, 1.0))
		var ground := world.terrain_height(world.cell_at(player.global_position))
		ExploreModels.flap(griffon, _t, player.global_position.y > ground + 0.6)
		if not player.is_alive() or player.global_position.y < WorldGenerator.UNDERGROUND:
			mount = null
			player.visual.position.y = 0.0
	elif griffon and is_instance_valid(griffon):
		ExploreModels.flap(griffon, _t, false)
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 1.0
	_offer_whistle()
	_spawn_tick -= 1.0
	if _spawn_tick <= 0.0:
		_spawn_tick = 6.0
		_wild_spawns()
	_update_islands()


## Les parties qui avaient déjà reçu l'héritage des dragons reçoivent le sifflet.
func _offer_whistle() -> void:
	if whistle_given:
		return
	var st := get_tree().get_first_node_in_group("story") as Story
	if st == null or not st.passed("vharok_2"):
		return
	whistle_given = true
	var it := Items.get_item("sifflet_griffon")
	if it and player.inventory.count(it) == 0:
		player.inventory.add(it, 1)
		player.feat.emit("Obtenu : Sifflet du griffon", it.rarity_color())
		player.notify.emit("Vharok t'envoie un sifflet d'os : le griffon des cimes répondra à ton appel (choisis-le avec C, puis V).")


## Vitesse du héros (à cheval : bien plus vite).
func speed_mult() -> float:
	if is_flying():
		return GRIFFON_SPEED
	if is_riding() and mount is Enemy:
		return 1.6 + 0.2 * int(mount.get_meta("evo", 0))
	return Horse.RIDE_SPEED if is_riding() else 1.0


# ---------------------------------------------------------------- chevaux sauvages

func spawn_horse(pos: Vector3, tame := false, index := -1) -> Horse:
	var h := Horse.new()
	h.setup("cheval", index)
	h.world = world
	h.tamed = tame
	world.get_node("Village").add_child(h)
	pos.y = world.ground_height_at(pos + Vector3(0, 3, 0))
	h.global_position = pos
	h.home = pos
	return h


func _wild_spawns() -> void:
	if player.global_position.y < WorldGenerator.UNDERGROUND:
		return
	var wild := horses().filter(func(h): return not h.tamed)
	for h in wild:
		if not h.following and h.global_position.distance_to(player.global_position) > DESPAWN:
			h.queue_free()
	wild = wild.filter(func(h): return is_instance_valid(h) and not h.is_queued_for_deletion())
	if wild.size() >= MAX_WILD:
		return
	for i in 8:
		var a := randf() * TAU
		var p := player.global_position + Vector3(cos(a), 0, sin(a)) * randf_range(SPAWN_MIN, SPAWN_MAX)
		var c := world.cell_at(p)
		if world.terrain_type(c) != WorldGenerator.GRASS:
			continue
		var r := world.region_at(p)
		if r == null or not WILD.has(r.id) or randi() % 4 >= int(WILD[r.id]) + 1:
			continue
		spawn_horse(world.cell_center(c))
		return


# ---------------------------------------------------------------- barques

## Pose une barque sur l'eau devant le héros. Renvoie le texte d'erreur (« » si c'est fait).
func place_boat(p: Player, kind := "barque") -> String:
	var fwd := Vector3(p.facing.x, 0, p.facing.z).normalized()
	for d in [1.6, 2.4, 3.2]:
		var at: Vector3 = p.global_position + fwd * d
		var c := world.cell_at(at)
		var t := world.terrain_type(c)
		if t == WorldGenerator.WATER or t == WorldGenerator.DEEP:
			spawn_boat(Vector3(at.x, world.water_surface, at.z), atan2(fwd.x, fwd.z), kind)
			VoxelBurst.spawn(world, at, Color(0.75, 0.9, 1.0), 14, 2.5, 0.08, 0.4, "up", 8.0, false)
			Sound.play("dig", at)
			return ""
	return "Il faut être face à l'eau pour mettre %s à l'eau." % ("la barque" if kind == "barque" else "le voilier")


func spawn_boat(pos: Vector3, rot := 0.0, kind := "barque") -> Node3D:
	var b: Node3D
	if kind == "voilier":
		b = Node3D.new()
		var m := ExploreModels.sailboat()
		m.name = "Modele"
		m.position.y = 0.15
		b.add_child(m)
		b.name = "Voilier"
	else:
		b = BOAT_MODEL.instantiate() as Node3D
		b.name = "Barque"
	b.set_meta("kind", kind)
	world.add_child(b)
	b.global_position = pos - Vector3(0, 0.05, 0)
	b.rotation.y = rot
	var lab := Label3D.new()
	lab.text = "%s\nF : monter" % ("Voilier" if kind == "voilier" else "Barque")
	lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lab.font_size = 28
	lab.pixel_size = 0.006
	lab.outline_size = 8
	lab.modulate = Color("e8d8b0")
	lab.position.y = 5.2 if kind == "voilier" else 1.2
	b.add_child(lab)
	b.set_meta("label", lab)
	boats.append(b)
	return b


# ---------------------------------------------------------------- îles au trésor

## Coffres des îles proches (les îles elles-mêmes sont créées avec le monde).
func _update_islands() -> void:
	if player.global_position.y < WorldGenerator.UNDERGROUND:
		return
	var near := {}
	for isl in world.islands_near(player.global_position, 3):
		near[isl.id] = true
		if not _island_nodes.has(isl.id):
			var n := CHEST_MODEL.instantiate() as Node3D
			world.add_child(n)
			var pos: Vector3 = isl.pos
			pos.y = world.ground_height_at(pos + Vector3(0, 5, 0))
			n.global_position = pos
			var lab := Label3D.new()
			lab.text = "Coffre vide" if opened.has(isl.id) else "Trésor de l'île\nF : ouvrir"
			lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			lab.font_size = 30
			lab.pixel_size = 0.007
			lab.outline_size = 8
			lab.modulate = Color(0.7, 0.7, 0.7) if opened.has(isl.id) else Color("ffd24a")
			lab.position.y = 1.4
			n.add_child(lab)
			n.set_meta("label", lab)
			_island_nodes[isl.id] = n
	for id in _island_nodes.keys():
		if not near.has(id):
			if is_instance_valid(_island_nodes[id]):
				_island_nodes[id].queue_free()
			_island_nodes.erase(id)


func _open_island_chest(id: String, n: Node3D) -> void:
	opened[id] = true
	var loot := [[Items.get_item("perle"), randi_range(1, 3)], [Items.get_item("piece_or"), randi_range(20, 45)]]
	if randf() < 0.5:
		loot.append([Items.get_item("lingot_or"), randi_range(1, 2)])
	if not world.wild_loot.is_empty():
		loot.append([world.wild_loot.pick_random(), 1])
	var rare := RareDrops.roll_chest("ile")
	loot.append_array(rare)
	RareDrops.announce(get_tree().get_first_node_in_group("player") as Player, rare)
	for i in loot.size():
		var a := TAU * i / loot.size()
		if loot[i][0]:
			world.spawn_pickup(loot[i][0], n.global_position + Vector3(cos(a), 0, sin(a)) * 1.2, loot[i][1])
	VoxelBurst.spawn(world, n.global_position + Vector3(0, 0.8, 0), Color("ffd24a"), 24, 4.0, 0.1, 0.7, "up", 4.0)
	var lab := n.get_meta("label") as Label3D
	if lab:
		lab.text = "Coffre vide"
		lab.modulate = Color(0.7, 0.7, 0.7)
	player.notify.emit("Trésor de l'île : %d trésors !" % loot.size())
	island_chest_opened.emit(id)


# ---------------------------------------------------------------- sauvegarde

func export_state() -> Dictionary:
	var hs := []
	for h in horses():
		if h.tamed:
			hs.append(h.export_state())
	var bs := []
	for b in boats:
		if is_instance_valid(b):
			bs.append([b.global_position.x, b.global_position.y, b.global_position.z, b.rotation.y, b.get_meta("kind", "barque")])
	var gr := []
	if griffon and is_instance_valid(griffon) and not is_flying():
		gr = [griffon.global_position.x, griffon.global_position.y, griffon.global_position.z]
	return {"horses": hs, "boats": bs, "opened": opened.keys(), "griffon": gr, "whistle": whistle_given}


func import_state(d: Dictionary) -> void:
	if mount:
		dismount()
	for h in horses():
		h.queue_free()
	for b in boats:
		if is_instance_valid(b):
			b.queue_free()
	boats.clear()
	for h in d.get("horses", []):
		spawn_horse(Vector3(h.pos[0], h.pos[1], h.pos[2]), true, int(h.m))
	for b in d.get("boats", []):
		spawn_boat(Vector3(b[0], b[1], b[2]), float(b[3]), str(b[4]) if b.size() > 4 else "barque")
	if griffon and is_instance_valid(griffon):
		griffon.queue_free()
	griffon = null
	var gr: Array = d.get("griffon", [])
	if gr.size() == 3:
		griffon = _make_griffon()
		griffon.global_position = Vector3(gr[0], gr[1], gr[2])
	whistle_given = bool(d.get("whistle", false))
	opened = {}
	for k in d.get("opened", []):
		opened[str(k)] = true
