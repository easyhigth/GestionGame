class_name MountainCaves
extends Node
## Grottes des montagnes, à la façon de Minecraft : au pied des falaises, une bouche sombre entre deux rochers.
## E : on entre dans un réseau de cavernes (sur 3 niveaux, de plus en plus profonds et dangereux).
## Les parois se creusent à la pioche, bloc par bloc : derrière, la roche continue (on peut percer ses propres
## galeries) et des filons de fer, d'or, de cristal et de mithril affleurent. Monstres, coffres, et un passage
## qui descend plus bas. Ce qui a été creusé et les coffres ouverts sont sauvegardés.

signal entered(id: String, level: int)
signal exited(id: String)
signal chest_opened(id: String)
signal mined_ore(item_id: String)

const FLOOR_Y := -260
const SIZE := 56
const LEVELS := 3
const WALL_H := 4
## Une entrée au plus par morceau du monde (16 × 16) ayant une falaise de roche.
const ENTRANCE_CHANCE := 0.3
const MIN_CLIFF := 1.5
const CHEST_MODEL := preload("res://assets/furniture/coffre.glb")
const ROCK := preload("res://assets/environment/models/rock_big.glb")
## Ce que rend un bloc de minerai : [objet, minimum, maximum].
const ORE_DROPS := {"bloc_minerai_fer": ["iron_ore", 1, 2], "bloc_minerai_or": ["or_brut", 1, 1],
	"bloc_minerai_cristal": ["", 1, 1], "bloc_minerai_mithril": ["mithril_brut", 1, 1]}
const GEMS := ["gemme_rubis", "gemme_saphir", "gemme_emeraude", "gemme_topaze", "gemme_amethyste"]
## Sous chaque capitale : [nom, thème (« crypte » ou « egout »)]. Même système que les grottes (3 niveaux, coffres),
## mais des salles et des couloirs de briques, et un gardien au fond.
const CITY_DUNGEONS := {"givre": ["Catacombes des Jarls", "crypte"], "sylvae": ["Cryptes de Lothëlia", "crypte"],
	"sables": ["Égouts de Qasr-Ammar", "egout"], "karg": ["Fosses de Gor-Karath", "egout"], "cendres": ["Catacombes de Minas Cendrys", "crypte"]}
const THEMES := {
	"crypte": {"wall": "bloc_briques", "wall2": "bloc_pierre_polie", "floor": "bloc_pierre_polie", "light": Color("ffb060"),
		"monsters": [["squelette", "esprit_follet", "squelette"], ["squelette", "esprit_follet", "seigneur_squelette"], ["squelette", "seigneur_squelette", "demon"]],
		"guard": "seigneur_squelette", "guard_name": "Gardien des tombeaux"},
	"egout": {"wall": "bloc_pierre_brute", "wall2": "bloc_briques", "floor": "bloc_pierre_polie", "light": Color("9aff8a"),
		"monsters": [["slime_acide", "araignee", "bandit"], ["slime_acide", "bandit", "bandit_chef"], ["slime_magma", "bandit_chef", "araignee"]],
		"guard": "bandit_chef", "guard_name": "Roi des égouts"},
}
## Monstres de chaque niveau.
const MONSTERS := [["araignee", "slime_acide", "squelette"], ["araignee", "squelette", "orc_brute", "slime_magma"],
	["squelette", "seigneur_squelette", "demon", "araignee"]]

var world: WorldGenerator
var player: Player
var active := false
var cave_id := ""
var level := 1
## Coffres ouverts : "grotte:niveau" -> [numéros]. Blocs creusés : "grotte:niveau" -> [[x, y, z], ...].
var opened := {}
var mined := {}
var _entrances := {}
var _entrance_nodes := {}
var _content: Node3D
var _interactables: Array = []
var _open := {}          # cases libres (sol de la grotte)
var _origin := Vector2i.ZERO
var _entry := {}
var _return_pos := Vector3.ZERO
var _fade: ColorRect
var _busy := false
var _tick := 0.0
var _saved := {}
var _player_light: OmniLight3D
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group("mountain_caves")
	_content = Node3D.new()
	_content.name = "GrotteMontagne"
	add_child(_content)
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color(0.02, 0.015, 0.01, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fade)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if not SaveGame.mountain_caves_state.is_empty():
		import_state(SaveGame.mountain_caves_state)
		SaveGame.mountain_caves_state = {}


func _grid() -> BuildGrid:
	return world.dungeon_grid if world else null


func _key() -> String:
	return "%s:%d" % [cave_id, level]


# ---------------------------------------------------------------- entrées dans le monde

## L'entrée de grotte d'un morceau du monde ({} s'il n'y en a pas) : au pied d'une falaise de roche.
func entrance_of(ch: Vector2i) -> Dictionary:
	if _entrances.has(ch):
		return _entrances[ch]
	var out := {}
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(world.world_seed, ch.x * 7919 + ch.y, 6161))
	if rng.randf() < ENTRANCE_CHANCE:
		for i in 14:
			var c := Vector2i(ch.x * WorldGenerator.CHUNK + rng.randi_range(2, 13), ch.y * WorldGenerator.CHUNK + rng.randi_range(2, 13))
			if world.terrain_type(c) != WorldGenerator.STONE:
				continue
			var hc := world.terrain_height(c)
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n: Vector2i = c - d
				var tn := world.terrain_type(n)
				if tn == WorldGenerator.WATER or tn == WorldGenerator.DEEP:
					continue
				if hc - world.terrain_height(n) >= MIN_CLIFF and world.decor_at(n) == WorldGenerator.D_NONE:
					out = {"id": "m%d_%d" % [ch.x, ch.y], "cell": n, "dir": d, "pos": world.cell_center(n)}
					break
			if not out.is_empty():
				break
	_entrances[ch] = out
	return out


## Les entrées des souterrains des capitales : un escalier dans une rue, près du palais.
var _city_entrances: Array = []
func city_entrances() -> Array:
	if not _city_entrances.is_empty() or world == null:
		return _city_entrances
	for city in world.cities:
		var info: Array = CITY_DUNGEONS.get(city.nation, [])
		if info.is_empty():
			continue
		var hall: Vector2i = city.hall
		var best := Vector2i(-9999, -9999)
		var bd := INF
		for st in city.streets:
			var d := Vector2(st - hall).length()
			if d >= 6.0 and d < bd:
				bd = d
				best = st
		if best.x == -9999:
			continue
		var cell: Vector2i = (city.center as Vector2i) + best
		var p := world.cell_center(cell)
		p.y = world.support_height(p, world.terrain_height(cell) + 0.3)
		_city_entrances.append({"id": "cata_" + str(city.nation), "cell": cell, "dir": Vector2i(0, 1), "pos": p,
			"theme": info[1], "name": info[0], "nation": city.nation})
	return _city_entrances


func entrances_near(pos: Vector3, radius_chunks := 2) -> Array:
	var out := []
	for e in city_entrances():
		if Vector2(e.pos.x - pos.x, e.pos.z - pos.z).length() < (radius_chunks + 0.5) * WorldGenerator.CHUNK:
			out.append(e)
	var ch := Vector2i(floori(pos.x) / WorldGenerator.CHUNK, floori(pos.z) / WorldGenerator.CHUNK)
	for dz in range(-radius_chunks, radius_chunks + 1):
		for dx in range(-radius_chunks, radius_chunks + 1):
			var c := ch + Vector2i(dx, dz)
			if c.x < 0 or c.y < 0 or c.x * WorldGenerator.CHUNK >= world.world_size.x or c.y * WorldGenerator.CHUNK >= world.world_size.y:
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


## La bouche de la grotte : deux rochers, une ouverture noire contre la falaise, une lueur de torche.
func _make_entrance(e: Dictionary) -> Node3D:
	if e.has("theme"):
		return _make_stairs(e)
	var n := Node3D.new()
	n.name = "EntreeGrotteMontagne_" + e.id
	world.add_child(n)
	n.global_position = e.pos
	var d: Vector2i = e.dir
	var fwd := Vector3(d.x, 0, d.y)
	n.look_at(n.global_position - fwd, Vector3.UP)
	for sx in [-1.3, 1.3]:
		var r := ROCK.instantiate() as Node3D
		n.add_child(r)
		r.position = Vector3(sx, 0, -0.2)
		r.scale = Vector3(0.7, 1.1, 0.7)
	var hole := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(1.8, 2.2)
	hole.mesh = qm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.02, 0.015, 0.01)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	hole.material_override = m
	hole.position = Vector3(0, 1.1, -0.45)
	n.add_child(hole)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.65, 0.3)
	l.light_energy = 1.4
	l.omni_range = 5.0
	l.position = Vector3(0.9, 1.6, 0.3)
	n.add_child(l)
	var lab := Label3D.new()
	lab.text = "Grotte\nF : entrer"
	lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lab.font_size = 34
	lab.pixel_size = 0.007
	lab.outline_size = 9
	lab.modulate = Color("ffd9a0")
	lab.position.y = 2.8
	lab.no_depth_test = true
	n.add_child(lab)
	return n


func _make_stairs(e: Dictionary) -> Node3D:
	var n := Node3D.new()
	n.name = "EntreeSouterrain_" + e.id
	world.add_child(n)
	n.global_position = e.pos
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.55, 0.52, 0.48)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.03, 0.02, 0.02)
	dark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for sx in [-1.1, 1.1]:
		var p := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.5, 2.6, 0.5)
		p.mesh = bm
		p.material_override = stone
		p.position = Vector3(sx, 1.3, 0)
		n.add_child(p)
	var top := MeshInstance3D.new()
	var tb := BoxMesh.new()
	tb.size = Vector3(2.8, 0.45, 0.6)
	top.mesh = tb
	top.material_override = stone
	top.position = Vector3(0, 2.75, 0)
	n.add_child(top)
	# les marches qui s'enfoncent dans le noir
	for i in 4:
		var s := MeshInstance3D.new()
		var sb := BoxMesh.new()
		sb.size = Vector3(1.7, 0.08, 0.45)
		s.mesh = sb
		s.material_override = stone if i < 2 else dark
		s.position = Vector3(0, 0.05 - i * 0.12, -0.1 - i * 0.4)
		n.add_child(s)
	var hole := MeshInstance3D.new()
	var hb := BoxMesh.new()
	hb.size = Vector3(1.7, 0.02, 1.4)
	hole.mesh = hb
	hole.material_override = dark
	hole.position = Vector3(0, 0.02, -1.2)
	n.add_child(hole)
	var l := OmniLight3D.new()
	l.light_color = (THEMES[e.theme] as Dictionary).light
	l.light_energy = 1.3
	l.omni_range = 5.0
	l.position = Vector3(0, 2.2, 0.6)
	n.add_child(l)
	var lab := Label3D.new()
	lab.text = "%s\nF : descendre" % e.name
	lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lab.font_size = 34
	lab.pixel_size = 0.007
	lab.outline_size = 9
	lab.modulate = Color("ffd9a0")
	lab.position.y = 3.6
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
			if Vector2(e.pos.x - p.global_position.x, e.pos.z - p.global_position.z).length() < 2.6:
				enter(e)
				return true
		return false
	for it in _interactables:
		if it.used or not is_instance_valid(it.node):
			continue
		if Vector2(it.pos.x - p.global_position.x, it.pos.z - p.global_position.z).length() < 2.2:
			match it.kind:
				"exit":
					if level > 1:
						_go_level(level - 1)
					else:
						leave()
				"down":
					_go_level(level + 1)
				"chest":
					_open_chest(it)
			return true
	return false


func enter(e: Dictionary) -> void:
	var dm := get_tree().get_first_node_in_group("dungeons")
	var uw := get_tree().get_first_node_in_group("caves")
	if active or _grid() == null or (dm and dm.is_inside()) or (uw and uw.active):
		return
	_entry = e
	_return_pos = e.pos + Vector3(e.dir.x, 0, e.dir.y) * -1.6
	_go_level(1)


func _go_level(lv: int) -> void:
	_busy = true
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 0.35)
	tw.tween_callback(func():
		_cleanup(false)
		_build(_entry, lv)
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
		player.global_position = Vector3(_return_pos.x, world.ground_height_at(_return_pos + Vector3(0, 40, 0)), _return_pos.z)
		player.snap_camera()
		exited.emit(id)
		_busy = false)
	tw.tween_property(_fade, "color:a", 0.0, 0.5)


# ---------------------------------------------------------------- la grotte

func floor_pos(c: Vector2i) -> Vector3:
	return Vector3(c.x + 0.5, FLOOR_Y, c.y + 0.5)


## Cavernes naturelles (automate cellulaire), une seule zone d'un seul tenant, entrée en bas au milieu.
func _layout(rng: RandomNumberGenerator) -> Dictionary:
	var cells := {}
	for y in SIZE:
		for x in SIZE:
			if x > 1 and y > 1 and x < SIZE - 2 and y < SIZE - 2 and rng.randf() < 0.53:
				cells[Vector2i(x, y)] = true
	for it in 5:
		var nxt := {}
		for y in range(1, SIZE - 1):
			for x in range(1, SIZE - 1):
				var n := 0
				for dy in [-1, 0, 1]:
					for dx in [-1, 0, 1]:
						if (dx != 0 or dy != 0) and cells.has(Vector2i(x + dx, y + dy)):
							n += 1
				var c := Vector2i(x, y)
				if (cells.has(c) and n >= 4) or (not cells.has(c) and n >= 5):
					nxt[c] = true
		cells = nxt
	# l'entrée : une salle ronde en bas
	var start := Vector2i(SIZE / 2, SIZE - 6)
	for dy in range(-3, 4):
		for dx in range(-3, 4):
			if Vector2(dx, dy).length() <= 3.2:
				cells[start + Vector2i(dx, dy)] = true
	# on ne garde que ce qui est relié à l'entrée
	var keep := {start: true}
	var stack := [start]
	while not stack.is_empty():
		var c: Vector2i = stack.pop_back()
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if cells.has(n) and not keep.has(n):
				keep[n] = true
				stack.append(n)
	return keep


func _theme() -> Dictionary:
	return THEMES.get(_entry.get("theme", ""), {})


func _floor_item() -> ItemData:
	var th := _theme()
	if not th.is_empty():
		return Items.get_item(th.floor)
	return Items.get_item("bloc_pierre_brute" if level == 1 else "bloc_roche_profonde")


## Bloc de paroi : roche, ou minerai selon la profondeur.
func _wall_item(rng: RandomNumberGenerator, lv: int) -> ItemData:
	var th := _theme()
	if not th.is_empty():
		return Items.get_item(th.wall2 if rng.randf() < 0.25 else th.wall)
	var r := rng.randf()
	if lv >= 3 and r < 0.015:
		return Items.get_item("bloc_minerai_mithril")
	if lv >= 2 and r < 0.045:
		return Items.get_item("bloc_minerai_or")
	if lv >= 2 and r < 0.075:
		return Items.get_item("bloc_minerai_cristal")
	if r < 0.14:
		return Items.get_item("bloc_minerai_fer")
	return Items.get_item("bloc_pierre_brute" if lv == 1 else "bloc_roche_profonde")


func _wall_column(c: Vector2i, rng: RandomNumberGenerator) -> void:
	var grid := _grid()
	for h in WALL_H:
		var k := Vector3i(c.x, FLOOR_Y + h, c.y)
		if grid.block_at(k) == null:
			grid.place_block(k, _wall_item(rng, level))


func _build(e: Dictionary, lv: int) -> void:
	cave_id = e.id
	level = lv
	active = true
	_interactables.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([world.world_seed, e.cell.x, e.cell.y, lv])
	_rng.seed = rng.seed + 1
	_origin = Vector2i(clampi(e.cell.x - SIZE / 2, 0, world.world_size.x - SIZE), clampi(e.cell.y - SIZE / 2, 0, world.world_size.y - SIZE))
	var themed := e.has("theme")
	var local := _crypt_layout(rng) if themed else _layout(rng)
	_open = {}
	for c in local:
		_open[c + _origin] = true
	var grid := _grid()
	var floor_it := _floor_item()
	for c in _open:
		grid.place_block(Vector3i(c.x, FLOOR_Y - 1, c.y), floor_it)
	var walls := {}
	for c in _open:
		for dy in [-1, 0, 1]:
			for dx in [-1, 0, 1]:
				var n: Vector2i = c + Vector2i(dx, dy)
				if not _open.has(n):
					walls[n] = true
	for w in walls:
		grid.place_block(Vector3i(w.x, FLOOR_Y - 1, w.y), floor_it)
		_wall_column(w, rng)
	# lumières : champignons et cristaux luisants
	var cells := _open.keys()
	cells.sort()
	for i in 12 + lv * 3:
		var c: Vector2i = cells[rng.randi() % cells.size()]
		var lc: Color = _theme().light if themed else [Color("6ad8ff"), Color("9aff8a"), Color("ffb070")][rng.randi() % 3]
		# une lueur qui palpite doucement, et sa source bien visible (grappe de cristaux ou de champignons)
		var l := FlickerLight.make(lc, 1.8, 8.0, 0.1)
		l.speed = 1.6
		_content.add_child(l)
		l.global_position = floor_pos(c) + Vector3(0, 1.2, 0)
		_content.add_child(_glow_cluster(lc, rng))
		(_content.get_child(_content.get_child_count() - 1) as Node3D).global_position = floor_pos(c)
	# entrée / sortie, passage vers le bas, coffres, monstres
	var start := _origin + Vector2i(SIZE / 2, SIZE - 6)
	_add_marker(start + Vector2i(0, 2), "exit", ("Sortie\nF : remonter dans la ville" if themed else "Sortie\nF : remonter") if lv == 1 else "Remonter\nF : niveau %d" % (lv - 1), Color("ffe0a0"))
	var far := start
	var far_d := 0.0
	for c in cells:
		var dd: float = Vector2(c).distance_to(Vector2(start))
		if dd > far_d:
			far_d = dd
			far = c
	if lv < LEVELS:
		_add_marker(far, "down", ("Escalier\nF : descendre (niveau %d)" if themed else "Galerie profonde\nF : descendre (niveau %d)") % (lv + 1), Color("ff9a6a"))
	elif themed:
		_spawn_guard(far)
	var done: Array = opened.get(_key(), [])
	var placed := 0
	for i in 40:
		if placed >= 2 + lv:
			break
		var c: Vector2i = cells[rng.randi() % cells.size()]
		if Vector2(c).distance_to(Vector2(start)) < 10.0 or c == far:
			continue
		_add_chest(c, placed, done.has(placed))
		placed += 1
	_spawn_monsters(cells, start, rng, lv)
	# ce que le héros avait déjà creusé
	for k in mined.get(_key(), []):
		_carve(Vector3i(int(k[0]), int(k[1]), int(k[2])), false)
	_set_lighting(true)
	player.global_position = floor_pos(start) + Vector3(0, 0.1, 0)
	player.snap_camera()
	entered.emit(cave_id, lv)
	if themed:
		player.notify.emit("%s, niveau %d : %s" % [e.name, lv, "des salles oubliées, des tombeaux, et ce qui y rôde." if lv < LEVELS else "le dernier niveau. Un gardien veille sur le plus grand trésor."])
	elif lv == 1:
		player.notify.emit("Une grotte dans la montagne... Creuse les parois à la pioche : fer, or, cristaux et mithril s'y cachent.")
	else:
		player.notify.emit("Niveau %d de la grotte : plus profond, plus dangereux, plus riche." % lv)


func _spawn_monsters(cells: Array, start: Vector2i, rng: RandomNumberGenerator, lv: int) -> void:
	var scene := load("res://scenes/enemies/enemy.tscn") as PackedScene
	var z := world.zone_at(_entry.pos)
	var base_lv: int = (z.level as Vector2i).x if not z.is_empty() else 3
	var mlist: Array = _theme().get("monsters", MONSTERS)
	var kinds: Array = mlist[clampi(lv - 1, 0, mlist.size() - 1)]
	var count := 4 + lv * 2
	var n := 0
	for i in 60:
		if n >= count:
			break
		var c: Vector2i = cells[rng.randi() % cells.size()]
		if Vector2(c).distance_to(Vector2(start)) < 12.0:
			continue
		var e := scene.instantiate() as Enemy
		e.data = load("res://data/enemies/%s.tres" % kinds[rng.randi() % kinds.size()])
		e.level = base_lv + (lv - 1) * 3
		e.power = 1.0 + 0.06 * e.level
		_content.add_child(e)
		e.global_position = floor_pos(c)
		e.home = e.global_position
		n += 1


## Salles reliées par des couloirs (un arbre au hasard sur une grille de 5 × 5 salles), une salle d'entrée en bas.
func _crypt_layout(rng: RandomNumberGenerator) -> Dictionary:
	var cells := {}
	var n := 5
	var step := 10
	var centers := {}
	for j in n:
		for i in n:
			var c := Vector2i(4 + i * step + rng.randi_range(0, 2), 4 + j * step + rng.randi_range(0, 2))
			centers[Vector2i(i, j)] = c
			var hw := rng.randi_range(2, 3)
			var hh := rng.randi_range(2, 3)
			for y in range(-hh, hh + 1):
				for x in range(-hw, hw + 1):
					cells[c + Vector2i(x, y)] = true
	# un arbre couvrant au hasard : chaque salle reliée à une voisine déjà reliée
	var linked := {Vector2i(n / 2, n - 1): true}
	var todo := []
	for k in centers:
		if not linked.has(k):
			todo.append(k)
	while not todo.is_empty():
		var shuffled := todo.duplicate()
		for i in range(shuffled.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var tmp = shuffled[i]
			shuffled[i] = shuffled[j]
			shuffled[j] = tmp
		var done := false
		for k in shuffled:
			var opts := []
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if linked.has(k + d):
					opts.append(k + d)
			if opts.is_empty():
				continue
			var o: Vector2i = opts[rng.randi() % opts.size()]
			_corridor(cells, centers[k], centers[o])
			linked[k] = true
			todo.erase(k)
			done = true
			break
		if not done:
			break
	# quelques boucles en plus
	for i in 4:
		var a := Vector2i(rng.randi_range(0, n - 2), rng.randi_range(0, n - 1))
		_corridor(cells, centers[a], centers[a + Vector2i(1, 0)])
	# l'entrée : reliée à la salle du bas, au milieu
	var start := Vector2i(SIZE / 2, SIZE - 6)
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			cells[start + Vector2i(dx, dy)] = true
	_corridor(cells, start, centers[Vector2i(n / 2, n - 1)])
	var out := {}
	for c in cells:
		if c.x > 1 and c.y > 1 and c.x < SIZE - 2 and c.y < SIZE - 2:
			out[c] = true
	return out


func _corridor(cells: Dictionary, a: Vector2i, b: Vector2i) -> void:
	var c := a
	while c.x != b.x:
		cells[c] = true
		cells[c + Vector2i(0, 1)] = true
		c.x += signi(b.x - c.x)
	while c.y != b.y:
		cells[c] = true
		cells[c + Vector2i(1, 0)] = true
		c.y += signi(b.y - c.y)
	cells[b] = true


## Le gardien du dernier niveau des souterrains d'une capitale.
func _spawn_guard(c: Vector2i) -> void:
	var th := _theme()
	var e := (load("res://scenes/enemies/enemy.tscn") as PackedScene).instantiate() as Enemy
	var d := (load("res://data/enemies/%s.tres" % th.guard) as EnemyData).duplicate() as EnemyData
	d.display_name = th.guard_name
	e.data = d
	var z := world.zone_at(_entry.pos)
	e.level = ((z.level as Vector2i).y if not z.is_empty() else 8) + 6
	e.power = 1.6 + 0.05 * e.level
	e.set_meta("guardian", true)
	_content.add_child(e)
	e.global_position = floor_pos(c)
	e.home = e.global_position
	e.visual.scale *= 1.4


func _add_marker(c: Vector2i, kind: String, text: String, col: Color) -> void:
	var n := Node3D.new()
	_content.add_child(n)
	n.global_position = floor_pos(c)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.6
	tm.outer_radius = 0.85
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.emission_enabled = true
	m.emission = col
	tm.material = m
	ring.mesh = tm
	ring.position.y = 0.05
	n.add_child(ring)
	var l := OmniLight3D.new()
	l.light_color = col
	l.light_energy = 1.2
	l.omni_range = 6.0
	l.position.y = 1.5
	n.add_child(l)
	_label(n, text, 2.4, col)
	_interactables.append({"node": n, "pos": n.global_position, "kind": kind, "used": false})


func _label(parent: Node3D, text: String, y: float, col: Color) -> Label3D:
	var lb := Label3D.new()
	lb.text = text
	lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lb.font_size = 32
	lb.pixel_size = 0.006
	lb.outline_size = 9
	lb.modulate = col
	lb.position.y = y
	# tout contre le panneau, le texte ne mange pas l'écran
	lb.visibility_range_begin = 3.5
	lb.visibility_range_begin_margin = 0.6
	lb.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	parent.add_child(lb)
	return lb


func _add_chest(c: Vector2i, index: int, used: bool) -> void:
	var n := CHEST_MODEL.instantiate() as Node3D
	_content.add_child(n)
	n.global_position = floor_pos(c)
	var lab := _label(n, "Vide" if used else "Coffre oublié\nF : ouvrir", 1.6, Color(0.7, 0.7, 0.7) if used else Color("ffd24a"))
	_interactables.append({"node": n, "pos": n.global_position, "kind": "chest", "used": used, "label": lab, "index": index})


func _open_chest(it: Dictionary) -> void:
	it.used = true
	var list: Array = opened.get(_key(), [])
	list.append(it.index)
	opened[_key()] = list
	var loot := [[Items.get_item("piece_or"), randi_range(10, 25) * level], [Items.get_item("iron_ore"), randi_range(2, 5)]]
	if level >= 2:
		loot.append([Items.get_item(GEMS.pick_random()), 1])
	if level >= 3 and randf() < 0.5:
		loot.append([Items.get_item("mithril_brut"), 1])
	if randf() < 0.4 and not world.wild_loot.is_empty():
		loot.append([world.wild_loot.pick_random(), 1])
	if not _theme().is_empty():
		loot.append([Items.get_item("lingot_or"), randi_range(1, level)])
		if level >= 3:
			loot.append([Items.get_item("orichalque" if randf() < 0.4 else "cristal_aube"), 1])
	var rare := RareDrops.roll_chest("grotte")
	loot.append_array(rare)
	RareDrops.announce(player, rare)
	var pos: Vector3 = it.pos
	for i in loot.size():
		var a := TAU * i / loot.size()
		if loot[i][0]:
			world.spawn_pickup(loot[i][0], pos + Vector3(cos(a), 0, sin(a)) * 1.2, loot[i][1], _content)
	VoxelBurst.spawn(_content, pos + Vector3(0, 0.8, 0), Color("ffd24a"), 20, 4.0, 0.1, 0.7, "up", 4.0)
	if is_instance_valid(it.label):
		it.label.text = "Vide"
		it.label.modulate = Color(0.7, 0.7, 0.7)
	player.notify.emit("Coffre oublié ouvert : %d trésors." % loot.size())
	Sound.play("coins", pos)
	chest_opened.emit(cave_id)


# ---------------------------------------------------------------- creuser

## Vrai si ce bloc de la grille souterraine appartient à la grotte en cours (on peut le creuser).
func can_mine(key: Vector3i) -> bool:
	return active and key.y >= FLOOR_Y and key.y < FLOOR_Y + WALL_H and _grid().block_at(key) != null


## Le héros a cassé un bloc de paroi : toute la colonne s'ouvre, la roche continue derrière.
## Renvoie ce que rend le bloc ([objet, nombre]).
func mine(key: Vector3i) -> Array:
	var it := _grid().block_at(key)
	if it == null:
		return []
	var list: Array = mined.get(_key(), [])
	list.append([key.x, key.y, key.z])
	mined[_key()] = list
	_carve(key, true)
	if ORE_DROPS.has(it.id):
		var d: Array = ORE_DROPS[it.id]
		var id: String = d[0] if d[0] != "" else GEMS[randi() % GEMS.size()]
		mined_ore.emit(it.id)
		return [Items.get_item(id), randi_range(int(d[1]), int(d[2]))]
	return [it, 1]


func _carve(key: Vector3i, _live: bool) -> void:
	var grid := _grid()
	var c := Vector2i(key.x, key.z)
	for h in WALL_H:
		grid.remove_block(Vector3i(c.x, FLOOR_Y + h, c.y))
	_open[c] = true
	if grid.block_at(Vector3i(c.x, FLOOR_Y - 1, c.y)) == null:
		grid.place_block(Vector3i(c.x, FLOOR_Y - 1, c.y), _floor_item())
	# la roche continue derrière : de nouvelles parois autour de la case ouverte
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([cave_id, level, c.x, c.y])
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			var n := c + Vector2i(dx, dy)
			if _open.has(n):
				continue
			if grid.block_at(Vector3i(n.x, FLOOR_Y - 1, n.y)) == null:
				grid.place_block(Vector3i(n.x, FLOOR_Y - 1, n.y), _floor_item())
			_wall_column(n, rng)


# ---------------------------------------------------------------- lumière, nettoyage, sauvegarde

## Grappe de petits cristaux (ou champignons) luisants posée au sol.
func _glow_cluster(col: Color, rng: RandomNumberGenerator) -> Node3D:
	var root := Node3D.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = 2.2
	for i in rng.randi_range(3, 5):
		var mi := MeshInstance3D.new()
		var b := BoxMesh.new()
		var h := rng.randf_range(0.18, 0.55)
		b.size = Vector3(0.12, h, 0.12)
		mi.mesh = b
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = Vector3(rng.randf_range(-0.35, 0.35), h * 0.5, rng.randf_range(-0.35, 0.35))
		mi.rotation = Vector3(rng.randf_range(-0.3, 0.3), rng.randf() * TAU, rng.randf_range(-0.3, 0.3))
		root.add_child(mi)
	return root


func _set_lighting(on: bool) -> void:
	var scene_root: Node = world.get_parent()
	var sun := scene_root.get_node_or_null("Soleil") as DirectionalLight3D
	var env_node := scene_root.get_node_or_null("Ambiance") as WorldEnvironment
	var env: Environment = env_node.environment if env_node else null
	if on:
		if sun and not _saved.has("sun"):
			_saved["sun"] = [sun.light_energy, sun.shadow_enabled]
			sun.light_energy = 0.05
			sun.shadow_enabled = false
		if env and not _saved.has("env"):
			_saved["env"] = [env.background_color, env.ambient_light_color, env.ambient_light_energy]
			env.background_color = Color(0.01, 0.008, 0.006)
			env.ambient_light_color = Color(0.7, 0.6, 0.5)
			env.ambient_light_energy = 0.35   # grottes sombres : ce sont les torches et la lanterne qui éclairent
		if _player_light == null:
			# la lanterne du héros
			_player_light = FlickerLight.make(Color(1.0, 0.78, 0.5), 1.9, 9.5, 0.1)
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


func _cleanup(lights_off := true) -> void:
	active = false
	if lights_off:
		_set_lighting(false)
	var grid := _grid()
	if grid:
		grid.clear()
	for c in _content.get_children():
		c.queue_free()
	_interactables.clear()
	_open.clear()


func export_state() -> Dictionary:
	return {"opened": opened.duplicate(true), "mined": mined.duplicate(true)}


func import_state(d: Dictionary) -> void:
	opened = {}
	mined = {}
	var o: Dictionary = d.get("opened", {})
	for k in o:
		opened[k] = (o[k] as Array).map(func(x): return int(x))
	var m: Dictionary = d.get("mined", {})
	for k in m:
		mined[k] = (m[k] as Array).duplicate(true)
