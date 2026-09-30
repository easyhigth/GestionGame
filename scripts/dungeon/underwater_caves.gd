class_name UnderwaterCaves
extends Node
## Grottes sous-marines : au fond des eaux profondes, des entrées de grottes (rochers, cristaux bleus).
## En nageant jusqu'à l'une d'elles, E : on entre dans une grotte inondée (salles et galeries sous l'eau),
## avec des coffres (perles, or, trésors) et des poches d'air pour reprendre son souffle.
## E devant la sortie (anneau de bulles) : on remonte au-dessus de l'entrée.

signal entered(id: String)
signal exited(id: String)
signal chest_opened(id: String)

const FLOOR_Y := -160
const SIZE := 34
const WALL_H := 4
## Hauteur de l'eau dans la grotte (au-dessus du sol) : tout est inondé.
const WATER_H := 3.6
## Une entrée au plus par morceau du monde (16 x 16), s'il a de l'eau assez profonde.
const ENTRANCE_CHANCE := 0.35
const MIN_DEPTH := 3.5
const CHEST_MODEL := preload("res://assets/furniture/coffre.glb")
const CRYSTAL := preload("res://assets/environment/models/crystal_blue.glb")
const ROCK := preload("res://assets/environment/models/rock_big.glb")

var world: WorldGenerator
var player: Player
var active := false
var cave_id := ""
var rooms: Array[Rect2i] = []
## Coffres déjà ouverts : identifiant de grotte -> [numéros].
var opened := {}
var _entrances := {}       # morceau -> {"id", "cell", "pos"} ou {} s'il n'y en a pas
var _entrance_nodes := {}  # identifiant -> Node3D
var _content: Node3D
var _interactables: Array = []
var _air: Array = []       # positions des poches d'air
var _bounds := Rect2i()
var _return_pos := Vector3.ZERO
var _fade: ColorRect
var _busy := false
var _tick := 0.0
var _saved := {}
var _player_light: OmniLight3D


func _ready() -> void:
	add_to_group("caves")
	_content = Node3D.new()
	_content.name = "GrotteSousMarine"
	add_child(_content)
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0.05, 0.12, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fade)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if not SaveGame.caves_state.is_empty():
		import_state(SaveGame.caves_state)
		SaveGame.caves_state = {}


func _grid() -> BuildGrid:
	return world.dungeon_grid if world else null


# ---------------------------------------------------------------- entrées dans le monde

## L'entrée de grotte d'un morceau du monde ({} s'il n'y en a pas). Toujours la même pour un monde donné.
func entrance_of(ch: Vector2i) -> Dictionary:
	if _entrances.has(ch):
		return _entrances[ch]
	var out := {}
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(world.world_seed, ch.x * 7919 + ch.y, 4242))
	if rng.randf() < ENTRANCE_CHANCE:
		for i in 10:
			var c := Vector2i(ch.x * WorldGenerator.CHUNK + rng.randi_range(2, 13), ch.y * WorldGenerator.CHUNK + rng.randi_range(2, 13))
			if world.terrain_type(c) == WorldGenerator.DEEP and world.water_surface - world.terrain_height(c) >= MIN_DEPTH:
				out = {"id": "%d_%d" % [ch.x, ch.y], "cell": c, "pos": world.cell_center(c)}
				break
	_entrances[ch] = out
	return out


## Entrées proches d'une position (dans les morceaux autour).
func entrances_near(pos: Vector3, radius_chunks := 2) -> Array:
	var out := []
	var ch := Vector2i(floori(pos.x) / WorldGenerator.CHUNK, floori(pos.z) / WorldGenerator.CHUNK)
	for dz in range(-radius_chunks, radius_chunks + 1):
		for dx in range(-radius_chunks, radius_chunks + 1):
			var c := ch + Vector2i(dx, dz)
			if c.x < 0 or c.y < 0:
				continue
			var e := entrance_of(c)
			if not e.is_empty():
				out.append(e)
	return out


func _process(delta: float) -> void:
	if world == null:
		return
	if player == null:
		player = get_tree().get_first_node_in_group("player") as Player
		return
	if active:
		# mort dans la grotte : le héros s'est réveillé au village
		if player.global_position.y > WorldGenerator.UNDERGROUND:
			_cleanup()
		return
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 1.0
	if player.global_position.y < WorldGenerator.UNDERGROUND:
		return
	# affiche les entrées proches, retire les lointaines
	var near := {}
	for e in entrances_near(player.global_position):
		near[e.id] = true
		if not _entrance_nodes.has(e.id):
			_entrance_nodes[e.id] = _make_entrance(e)
	for id in _entrance_nodes.keys():
		if not near.has(id):
			if is_instance_valid(_entrance_nodes[id]):
				_entrance_nodes[id].queue_free()
			_entrance_nodes.erase(id)


func _make_entrance(e: Dictionary) -> Node3D:
	var n := Node3D.new()
	n.name = "EntreeGrotte_" + e.id
	world.add_child(n)
	n.global_position = e.pos
	for i in 3:
		var r := ROCK.instantiate() as Node3D
		n.add_child(r)
		var a := TAU * i / 3.0 + 0.5
		r.position = Vector3(cos(a), 0, sin(a)) * 1.4
		r.rotation.y = a
		r.scale = Vector3.ONE * 0.8
	for i in 2:
		var cr := CRYSTAL.instantiate() as Node3D
		n.add_child(cr)
		cr.position = Vector3(-0.6 + i * 1.2, 0, 0.9)
		cr.scale = Vector3.ONE * 0.7
	# le trou sombre
	var hole := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.9
	cyl.bottom_radius = 0.9
	cyl.height = 0.05
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.02, 0.03, 0.06)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cyl.material = m
	hole.mesh = cyl
	hole.position.y = 0.04
	n.add_child(hole)
	var l := OmniLight3D.new()
	l.light_color = Color("6ad8ff")
	l.light_energy = 1.6
	l.omni_range = 6.0
	l.position.y = 1.0
	n.add_child(l)
	# une colonne de bulles monte jusqu'à la surface : on repère l'entrée depuis la berge
	var col := _bubbles(e.pos + Vector3(0, 0.3, 0), 30)
	col.reparent(n)
	col.lifetime = maxf(1.0, (world.water_surface - e.pos.y) / 1.6)
	col.preprocess = col.lifetime
	var lab := Label3D.new()
	lab.text = "Grotte sous-marine\nE : entrer"
	lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lab.font_size = 34
	lab.pixel_size = 0.007
	lab.outline_size = 9
	lab.modulate = Color("bff0ff")
	lab.position.y = 2.2
	lab.no_depth_test = true
	n.add_child(lab)
	return n


# ---------------------------------------------------------------- interaction (E)

func try_interact(p: Player) -> bool:
	player = p
	if _busy or world == null:
		return false
	if not active:
		if p.global_position.y < WorldGenerator.UNDERGROUND:
			return false
		for e in entrances_near(p.global_position, 1):
			if Vector2(e.pos.x - p.global_position.x, e.pos.z - p.global_position.z).length() < 2.6 and p.global_position.y < world.water_surface - 0.5:
				enter(e)
				return true
		return false
	for it in _interactables:
		if it.used or not is_instance_valid(it.node):
			continue
		if Vector2(it.pos.x - p.global_position.x, it.pos.z - p.global_position.z).length() < 2.2:
			if it.kind == "exit":
				leave()
			else:
				_open_chest(it)
			return true
	return false


func enter(e: Dictionary) -> void:
	var dm := get_tree().get_first_node_in_group("dungeons")
	if active or _grid() == null or (dm and dm.is_inside()):
		return
	_busy = true
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 0.35)
	tw.tween_callback(func():
		_build(e)
		_busy = false)
	tw.tween_property(_fade, "color:a", 0.0, 0.5)


func leave() -> void:
	if not active:
		return
	_busy = true
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 0.35)
	tw.tween_callback(func():
		var id := cave_id
		_cleanup()
		world.load_area(_return_pos)
		player.global_position = _return_pos
		player.snap_camera()
		exited.emit(id)
		_busy = false)
	tw.tween_property(_fade, "color:a", 0.0, 0.5)


# ---------------------------------------------------------------- la grotte

func _floor_pos(c: Vector2i) -> Vector3:
	return Vector3(c.x + 0.5, FLOOR_Y, c.y + 0.5)


## Hauteur de l'eau à cette position dans la grotte (-INF hors de la grotte).
func water_top(pos: Vector3) -> float:
	if not active or pos.y > WorldGenerator.UNDERGROUND or not _bounds.has_point(world.cell_at(pos)):
		return -INF
	return FLOOR_Y + WATER_H


## Vrai dans une poche d'air (on y reprend son souffle).
func in_air_pocket(pos: Vector3) -> bool:
	for a in _air:
		if Vector2(a.x - pos.x, a.z - pos.z).length() < 1.4:
			return true
	return false


func _build(e: Dictionary) -> void:
	cave_id = e.id
	active = true
	_interactables.clear()
	_air.clear()
	_return_pos = Vector3(e.pos.x + 1.8, world.water_surface - 0.9, e.pos.z + 1.8)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(world.world_seed, e.cell.x, e.cell.y))
	var origin := Vector2i(clampi(e.cell.x - SIZE / 2, 0, world.world_size.x - SIZE), clampi(e.cell.y - SIZE / 2, 0, world.world_size.y - SIZE))
	_bounds = Rect2i(origin, Vector2i(SIZE, SIZE))
	var cells := _layout(rng, origin)
	var grid := _grid()
	var sand := Items.get_item("bloc_sable")
	var wall := Items.get_item("bloc_ardoise") if Items.get_item("bloc_ardoise") else Items.get_item("bloc_pierre_brute")
	var rock := Items.get_item("bloc_pierre_brute")
	for c in cells:
		grid.place_block(Vector3i(c.x, FLOOR_Y - 1, c.y), sand)
	var walls := {}
	for c in cells:
		for dy in [-1, 0, 1]:
			for dx in [-1, 0, 1]:
				var n: Vector2i = c + Vector2i(dx, dy)
				if not cells.has(n):
					walls[n] = true
	for w in walls:
		grid.place_block(Vector3i(w.x, FLOOR_Y - 1, w.y), rock)
		for h in WALL_H:
			grid.place_block(Vector3i(w.x, FLOOR_Y + h, w.y), wall if (w.x * 7 + w.y * 3 + h) % 5 else rock)
	# l'eau (une nappe à la surface) et la lumière bleue
	var water := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(SIZE, SIZE)
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color(0.2, 0.5, 0.75, 0.45)
	wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wm.cull_mode = BaseMaterial3D.CULL_DISABLED
	plane.material = wm
	water.mesh = plane
	_content.add_child(water)
	water.global_position = Vector3(origin.x + SIZE / 2.0, FLOOR_Y + WATER_H, origin.y + SIZE / 2.0)
	# décor : cristaux et algues
	for room in rooms:
		for i in rng.randi_range(2, 4):
			var c := room.position + Vector2i(rng.randi_range(1, room.size.x - 2), rng.randi_range(1, room.size.y - 2))
			var cr := CRYSTAL.instantiate() as Node3D
			_content.add_child(cr)
			cr.global_position = _floor_pos(c)
			cr.rotation.y = rng.randf() * TAU
			cr.scale = Vector3.ONE * rng.randf_range(0.5, 0.9)
		for i in rng.randi_range(4, 8):
			var c := room.position + Vector2i(rng.randi_range(0, room.size.x - 1), rng.randi_range(0, room.size.y - 1))
			_add_kelp(_floor_pos(c), rng)
		var l := OmniLight3D.new()
		l.light_color = Color("5ac8ff")
		l.light_energy = 1.2
		l.omni_range = 9.0
		_content.add_child(l)
		l.global_position = _floor_pos(room.get_center()) + Vector3(0, 2.5, 0)
	# sortie et poches d'air
	var entrance: Rect2i = rooms[0]
	_add_exit(entrance.get_center())
	_add_air(entrance.get_center() + Vector2i(2, 0))
	if rooms.size() > 2:
		var r2: Rect2i = rooms[rng.randi_range(2, rooms.size() - 1)]
		_add_air(r2.get_center())
	# coffres
	var done: Array = opened.get(cave_id, [])
	var n := 0
	for i in range(1, rooms.size()):
		var room: Rect2i = rooms[i]
		var c := room.position + Vector2i(rng.randi_range(1, room.size.x - 2), 1)
		_add_chest(c, n, done.has(n))
		n += 1
	_set_lighting(true)
	player.global_position = _floor_pos(entrance.get_center() + Vector2i(0, 1)) + Vector3(0, 1.0, 0)
	player.snap_camera()
	entered.emit(cave_id)
	player.notify.emit("Une grotte inondée... Surveille ton souffle : les poches d'air (bulles) te permettent de respirer.")


func _layout(rng: RandomNumberGenerator, origin: Vector2i) -> Dictionary:
	rooms.clear()
	var local: Array[Rect2i] = [Rect2i(SIZE / 2 - 4, SIZE / 2 - 4, 8, 8)]
	var tries := 0
	var want := rng.randi_range(4, 5)
	while local.size() < want and tries < 200:
		tries += 1
		var w := rng.randi_range(6, 9)
		var h := rng.randi_range(6, 9)
		var rr := Rect2i(rng.randi_range(2, SIZE - w - 2), rng.randi_range(2, SIZE - h - 2), w, h)
		var ok := true
		for o in local:
			if rr.grow(2).intersects(o):
				ok = false
		if ok:
			local.append(rr)
	var cells := {}
	for rr in local:
		for y in range(rr.position.y, rr.end.y):
			for x in range(rr.position.x, rr.end.x):
				cells[Vector2i(x, y)] = true
	for i in range(1, local.size()):
		# relie chaque salle à la plus proche des précédentes
		var best := 0
		var bd := INF
		for j in i:
			var d := Vector2(local[i].get_center()).distance_to(Vector2(local[j].get_center()))
			if d < bd:
				bd = d
				best = j
		_corridor(cells, local[i].get_center(), local[best].get_center(), rng.randf() < 0.5)
	for rr in local:
		rooms.append(Rect2i(rr.position + origin, rr.size))
	var out := {}
	for c in cells:
		out[c + origin] = true
	return out


func _corridor(cells: Dictionary, a: Vector2i, b: Vector2i, x_first: bool) -> void:
	var p := a
	var steps := [Vector2i(signi(b.x - a.x), 0), Vector2i(0, signi(b.y - a.y))]
	if not x_first:
		steps.reverse()
	for st in steps:
		if st == Vector2i.ZERO:
			continue
		while (st.x != 0 and p.x != b.x) or (st.y != 0 and p.y != b.y):
			for k in [0, 1]:
				cells[p + (Vector2i(0, k) if st.x != 0 else Vector2i(k, 0))] = true
			p += st


func _add_kelp(at: Vector3, rng: RandomNumberGenerator) -> void:
	var g := Node3D.new()
	_content.add_child(g)
	g.global_position = at
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.2, 0.55, 0.3).lerp(Color(0.35, 0.6, 0.2), rng.randf())
	for i in rng.randi_range(2, 4):
		var b := MeshInstance3D.new()
		var bm := BoxMesh.new()
		var h := rng.randf_range(0.8, 2.2)
		bm.size = Vector3(0.1, h, 0.1)
		bm.material = m
		b.mesh = bm
		b.position = Vector3(rng.randf_range(-0.3, 0.3), h / 2.0, rng.randf_range(-0.3, 0.3))
		b.rotation.z = rng.randf_range(-0.2, 0.2)
		g.add_child(b)


func _bubbles(at: Vector3, amount: int) -> CPUParticles3D:
	var c := CPUParticles3D.new()
	c.amount = amount
	c.lifetime = 2.2
	c.preprocess = 2.2
	c.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	c.emission_sphere_radius = 0.4
	c.direction = Vector3.UP
	c.spread = 10.0
	c.initial_velocity_min = 1.2
	c.initial_velocity_max = 2.0
	c.gravity = Vector3.ZERO
	var mesh := SphereMesh.new()
	mesh.radius = 0.06
	mesh.height = 0.12
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.85, 0.95, 1.0, 0.7)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = m
	c.mesh = mesh
	_content.add_child(c)
	c.global_position = at
	return c


func _label(parent: Node3D, text: String, y: float, col: Color) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.font_size = 34
	l.pixel_size = 0.006
	l.outline_size = 9
	l.modulate = col
	l.position.y = y
	parent.add_child(l)
	return l


func _add_exit(c: Vector2i) -> void:
	var n := Node3D.new()
	_content.add_child(n)
	n.global_position = _floor_pos(c)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.7
	tm.outer_radius = 0.95
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("8af0ff")
	m.emission_enabled = true
	m.emission = Color("4ad0ff")
	tm.material = m
	ring.mesh = tm
	ring.position.y = 0.1
	n.add_child(ring)
	_bubbles(n.global_position, 40)
	_label(n, "Sortie\nE : remonter", 2.4, Color("bff6ff"))
	_interactables.append({"node": n, "pos": n.global_position, "kind": "exit", "used": false})


func _add_air(c: Vector2i) -> void:
	var at := _floor_pos(c)
	_air.append(at)
	_bubbles(at, 60)
	var n := Node3D.new()
	_content.add_child(n)
	n.global_position = at
	_label(n, "Poche d'air", 2.9, Color("e8f8ff"))
	var l := OmniLight3D.new()
	l.light_color = Color("c8f4ff")
	l.light_energy = 1.0
	l.omni_range = 4.0
	l.position.y = 2.0
	n.add_child(l)


func _add_chest(c: Vector2i, index: int, used: bool) -> void:
	var n := CHEST_MODEL.instantiate() as Node3D
	_content.add_child(n)
	n.global_position = _floor_pos(c)
	n.rotation.y = PI
	var lab := _label(n, "Vide" if used else "Coffre englouti\nE : ouvrir", 1.6, Color(0.7, 0.7, 0.7) if used else Color("ffd24a"))
	_interactables.append({"node": n, "pos": n.global_position, "kind": "chest", "used": used, "label": lab, "index": index})


func _open_chest(it: Dictionary) -> void:
	it.used = true
	var list: Array = opened.get(cave_id, [])
	list.append(it.index)
	opened[cave_id] = list
	var loot := [[Items.get_item("perle"), randi_range(1, 2)], [Items.get_item("piece_or"), randi_range(8, 20)]]
	if randf() < 0.3:
		loot.append([Items.get_item("lingot_or"), 1])
	if randf() < 0.45 and not world.wild_loot.is_empty():
		loot.append([world.wild_loot.pick_random(), 1])
	var rare := RareDrops.roll_chest("grotte")
	loot.append_array(rare)
	RareDrops.announce(get_tree().get_first_node_in_group("player") as Player, rare)
	var pos: Vector3 = it.pos
	for i in loot.size():
		var a := TAU * i / loot.size()
		if loot[i][0]:
			world.spawn_pickup(loot[i][0], pos + Vector3(cos(a), 0, sin(a)) * 1.2, loot[i][1], _content)
	VoxelBurst.spawn(_content, pos + Vector3(0, 0.8, 0), Color("ffd24a"), 20, 4.0, 0.1, 0.7, "up", 4.0)
	if is_instance_valid(it.label):
		it.label.text = "Vide"
		it.label.modulate = Color(0.7, 0.7, 0.7)
	player.notify.emit("Coffre englouti ouvert : %d trésors." % loot.size())
	chest_opened.emit(cave_id)


func _set_lighting(on: bool) -> void:
	var scene_root: Node = world.get_parent()
	var sun := scene_root.get_node_or_null("Soleil") as DirectionalLight3D
	var env_node := scene_root.get_node_or_null("Ambiance") as WorldEnvironment
	var env: Environment = env_node.environment if env_node else null
	if on:
		if sun and not _saved.has("sun"):
			_saved["sun"] = [sun.light_energy, sun.shadow_enabled]
			sun.light_energy = 0.1
			sun.shadow_enabled = false
		if env and not _saved.has("env"):
			_saved["env"] = [env.background_color, env.ambient_light_color, env.ambient_light_energy, env.fog_enabled]
			env.background_color = Color(0.01, 0.04, 0.09)
			env.ambient_light_color = Color(0.3, 0.55, 0.8)
			env.ambient_light_energy = 0.8
		if _player_light == null:
			_player_light = OmniLight3D.new()
			_player_light.light_color = Color(0.8, 0.95, 1.0)
			_player_light.light_energy = 0.9
			_player_light.omni_range = 7.0
			_player_light.position.y = 1.8
			player.add_child(_player_light)
	else:
		if sun and _saved.has("sun"):
			sun.light_energy = _saved.sun[0]
			sun.shadow_enabled = _saved.sun[1]
		if env and _saved.has("env"):
			env.background_color = _saved.env[0]
			env.ambient_light_color = _saved.env[1]
			env.ambient_light_energy = _saved.env[2]
		_saved.clear()
		if _player_light and is_instance_valid(_player_light):
			_player_light.queue_free()
		_player_light = null


func _cleanup() -> void:
	active = false
	_set_lighting(false)
	var grid := _grid()
	if grid:
		grid.clear()
	for c in _content.get_children():
		c.queue_free()
	_interactables.clear()
	_air.clear()
	rooms.clear()
	_bounds = Rect2i()


# ---------------------------------------------------------------- sauvegarde

func export_state() -> Dictionary:
	return {"opened": opened.duplicate(true)}


func import_state(d: Dictionary) -> void:
	opened = {}
	var o: Dictionary = d.get("opened", {})
	for k in o:
		opened[k] = (o[k] as Array).map(func(x): return int(x))
