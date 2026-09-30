class_name Livestock
extends Node
## Élevage : fait apparaître des bêtes sauvages dans les prés, rend domestiques celles qu'on mène à une
## mangeoire, les nourrit (réserve du village), récolte leurs produits (œufs, laine, lait) et fait naître
## des petits chaque jour. Les produits tombent près des bêtes ; un fermier de la grange les ramasse.

signal changed
## Une bête a donné un produit (pour le guide).
signal produced(item_id: String)
signal tamed(animal: FarmAnimal)

## Bêtes sauvages : combien au plus autour du héros, à quelle distance elles apparaissent et disparaissent.
const MAX_WILD := 8
const SPAWN_MIN := 26.0
const SPAWN_MAX := 44.0
const DESPAWN := 90.0
## Espèces sauvages selon la région (identifiant de région -> {espèce: poids}).
const WILD := {
	"prairie": {"poule": 3, "mouton": 3, "vache": 3},
	"foret": {"poule": 2, "mouton": 1},
	"bois_enchante": {"poule": 1},
	"marais": {"poule": 1},
	"montagnes": {"mouton": 3, "vache": 1},
	"toundra": {"mouton": 2},
}
## Distance à la mangeoire pour qu'une bête s'installe.
const TAME_DISTANCE := 4.5
## Petits : au plus ce nombre de bêtes par espèce ; il faut assez de nourriture en réserve.
const MAX_PER_SPECIES := 6
const BREED_FOOD := 40.0
## Produits laissés au sol près d'une bête au plus.
const MAX_ON_GROUND := 3

var world: WorldGenerator
var player: Player
var _tick := 0.0
var _spawn_tick := 2.0


func _ready() -> void:
	add_to_group("livestock")
	if world == null:
		world = get_tree().get_first_node_in_group("world") as WorldGenerator
	_connect_day.call_deferred()
	if not SaveGame.livestock_state.is_empty():
		import_state.call_deferred(SaveGame.livestock_state)
		SaveGame.livestock_state = {}
	else:
		_starter_flock.call_deferred()


func _connect_day() -> void:
	var dc := get_tree().get_first_node_in_group("day_cycle") as DayCycle
	if dc and not dc.day_started.is_connected(_on_day):
		dc.day_started.connect(_on_day)


func animals() -> Array:
	return get_tree().get_nodes_in_group("farm_animals").filter(func(a): return is_instance_valid(a) and not a.is_queued_for_deletion())


func domestic() -> Array:
	return animals().filter(func(a): return a.domestic)


func count(sp: String) -> int:
	return domestic().filter(func(a): return a.species == sp).size()


## Mangeoires posées : [position, ...]
func feeders() -> Array:
	var out := []
	if world == null:
		return out
	for k in world.build.furniture:
		var f: Dictionary = world.build.furniture[k]
		if (f.item as ItemData).id == "mangeoire":
			out.append(Vector3(f.col.x + 0.5, float(f.base), f.col.y + 0.5))
	return out


func spawn(sp: String, pos: Vector3, tame := false, index := -1) -> FarmAnimal:
	var a := FarmAnimal.new()
	a.setup(sp, index)
	a.world = world
	a.name = "%s_%d" % [sp, randi() % 100000]
	world.get_node("Village").add_child(a)
	pos.y = world.ground_height_at(pos + Vector3(0, 3, 0))
	a.global_position = pos
	a.home = pos
	a.domestic = tame
	return a


## Une petite troupe de poules pas loin du village (nouvelle partie).
func _starter_flock() -> void:
	if world == null:
		return
	var c := world.cell_center(world.spawn_cell)
	for i in 24:
		var a := randf() * TAU
		var pos := c + Vector3(cos(a), 0, sin(a)) * randf_range(16.0, 22.0)
		if world.terrain_type(world.cell_at(pos)) == WorldGenerator.GRASS and world.is_walkable(pos):
			for j in 3:
				spawn("poule", pos + Vector3(randf_range(-1.5, 1.5), 0, randf_range(-1.5, 1.5)))
			return


func _process(delta: float) -> void:
	if world == null or player == null:
		return
	_tick -= delta
	if _tick > 0.0:
		return
	var dt := 1.0 - _tick
	_tick = 1.0
	_tame_check()
	_produce(dt)
	_spawn_tick -= dt
	if _spawn_tick <= 0.0:
		_spawn_tick = 5.0
		_wild_spawns()


# ---------------------------------------------------------------- apprivoiser

func _tame_check() -> void:
	var fs := feeders()
	if fs.is_empty():
		return
	for a in animals():
		if a.domestic or not a.following:
			continue
		for f in fs:
			if Vector2(a.global_position.x - f.x, a.global_position.z - f.z).length() < TAME_DISTANCE:
				a.domestic = true
				a.following = false
				a.home = f + (a.global_position - f).normalized() * 1.5
				a.home.y = f.y
				VoxelBurst.spawn(a, a.global_position + Vector3(0, 1, 0), Color(1.0, 0.6, 0.7), 14, 2.2, 0.08, 0.5, "up", 5.0, false)
				Sound.play("pickup", a.global_position)
				player.notify.emit("%s s'installe dans ton enclos ! Nourrie par la réserve du village, elle donnera %s." % [
					a.info().name, (Items.get_item(a.info().product) as ItemData).display_name.to_lower()])
				tamed.emit(a)
				changed.emit()
				break


# ---------------------------------------------------------------- produits

## Un fermier de la grange est au travail (il ramasse les produits).
func _grange_worker() -> bool:
	var k := get_tree().get_first_node_in_group("kingdom") as Kingdom
	if k == null:
		return false
	for r in k.workplaces():
		if r.type and (r.type as RoomTypeData).id == "grange":
			for v in k.workers_of(r):
				if v.is_at_work():
					return true
	return false


func _produce(dt: float) -> void:
	var needs := get_tree().get_first_node_in_group("village_needs") as VillageNeeds
	var collector := -1
	for a in domestic():
		if a.is_baby():
			continue
		var inf: Dictionary = a.info()
		a.product_timer += dt
		if a.product_timer < float(inf.every):
			continue
		a.product_timer = 0.0
		var feed := float(inf.feed)
		if needs == null or needs.food_stock < feed:
			a.hungry = true
			continue
		a.hungry = false
		needs.food_stock -= feed
		var it := Items.get_item(inf.product)
		if it == null:
			continue
		if collector < 0:
			collector = 1 if _grange_worker() else 0
		if collector == 1:
			# le fermier de la grange ramasse : la nourriture va dans la réserve, la laine dans ton sac
			if it.is_food():
				needs.add_food(it.food)
			else:
				player.inventory.add(it, 1)
		else:
			if _on_ground(a.global_position, it.id) >= MAX_ON_GROUND:
				continue
			world.spawn_pickup(it, a.global_position + Vector3(randf_range(-0.6, 0.6), 0.1, randf_range(-0.6, 0.6)), 1)
		produced.emit(it.id)
	changed.emit()


func _on_ground(pos: Vector3, id: String) -> int:
	var n := 0
	for c in world.get_node("Village").get_children():
		if c is ItemPickup and not c.is_taken() and c.get("item") and c.item.id == id and c.global_position.distance_to(pos) < 4.0:
			n += 1
	return n


# ---------------------------------------------------------------- chaque jour : petits

func _on_day(_d: int) -> void:
	for a in domestic():
		a.grow_up()
	var needs := get_tree().get_first_node_in_group("village_needs") as VillageNeeds
	if needs == null or needs.food_stock < BREED_FOOD:
		return
	for sp in FarmAnimal.SPECIES:
		var adults := domestic().filter(func(a): return a.species == sp and not a.is_baby())
		if adults.size() < 2 or count(sp) >= MAX_PER_SPECIES:
			continue
		var mother: FarmAnimal = adults[randi() % adults.size()]
		var baby := spawn(sp, mother.global_position + Vector3(0.6, 0, 0.4), true, mother.model_index)
		baby.home = mother.home
		baby.baby_days = 1
		baby._apply_age()
		player.notify.emit("Un petit est né dans ton enclos : %s !" % FarmAnimal.SPECIES[sp].name.to_lower())
	changed.emit()


# ---------------------------------------------------------------- bêtes sauvages

func _wild_spawns() -> void:
	if player.global_position.y < WorldGenerator.UNDERGROUND:
		return
	var wild := animals().filter(func(a): return not a.domestic)
	for a in wild:
		if not a.following and a.global_position.distance_to(player.global_position) > DESPAWN:
			a.queue_free()
	wild = wild.filter(func(a): return is_instance_valid(a) and not a.is_queued_for_deletion())
	if wild.size() >= MAX_WILD:
		return
	var pos := Vector3.INF
	var r: RegionData = null
	for i in 8:
		var ang := randf() * TAU
		var p := player.global_position + Vector3(cos(ang), 0, sin(ang)) * randf_range(SPAWN_MIN, SPAWN_MAX)
		var cell := world.cell_at(p)
		if world.terrain_type(cell) != WorldGenerator.GRASS or not world.is_walkable(world.cell_center(cell)):
			continue
		r = world.region_at(p)
		if r == null or not WILD.has(r.id):
			continue
		pos = world.cell_center(cell)
		break
	if pos == Vector3.INF:
		return
	var weights: Dictionary = WILD[r.id]
	var total := 0.0
	for sp in weights:
		total += float(weights[sp])
	var x := randf() * total
	var chosen := ""
	for sp in weights:
		x -= float(weights[sp])
		if x <= 0.0:
			chosen = sp
			break
	if chosen == "":
		return
	for j in randi_range(2, 3 if chosen != "vache" else 2):
		spawn(chosen, pos + Vector3(randf_range(-1.8, 1.8), 0, randf_range(-1.8, 1.8)))


# ---------------------------------------------------------------- résumé et sauvegarde

func summary_text() -> String:
	var parts := []
	for sp in FarmAnimal.SPECIES:
		var n := count(sp)
		if n > 0:
			parts.append("%d %s" % [n, FarmAnimal.SPECIES[sp].plural if n > 1 else FarmAnimal.SPECIES[sp].name.to_lower()])
	if parts.is_empty():
		return ""
	var hungry := domestic().filter(func(a): return a.hungry).size()
	return "Élevage : %s%s%s" % [", ".join(PackedStringArray(parts)), ("  ·  %d %s faim (réserve vide)" % [hungry, "a" if hungry == 1 else "ont"]) if hungry > 0 else "",
		"  ·  le fermier de la grange ramasse les produits" if _grange_worker() else ""]


func export_state() -> Dictionary:
	return {"animals": domestic().map(func(a): return a.export_state())}


func import_state(d: Dictionary) -> void:
	for a in domestic():
		a.queue_free()
	for s in d.get("animals", []):
		if not FarmAnimal.SPECIES.has(str(s.sp)):
			continue
		var a := spawn(str(s.sp), Vector3(s.pos[0], s.pos[1], s.pos[2]), true, int(s.m))
		a.home = Vector3(s.home[0], s.home[1], s.home[2])
		a.baby_days = int(s.baby)
		a.product_timer = float(s.t)
		a._apply_age.call_deferred()
	changed.emit()
