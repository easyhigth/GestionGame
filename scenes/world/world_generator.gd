@tool
class_name WorldGenerator
extends Node3D
## Génère le monde 3D voxel (île en terrasses) à partir de bruits, puis installe le village de départ.
## Tous les réglages sont dans l'Inspecteur. Le bouton « Générer un aperçu »
## affiche le terrain directement dans l'éditeur (sans le village).
## 1 case = 1 mètre. Le sol est fait de colonnes de blocs, les décors sont des modèles voxel (.glb).

signal world_generated(seed_used: int)

@export_tool_button("Générer un aperçu", "Reload") var _btn_generate: Callable = _editor_preview
@export_tool_button("Effacer l'aperçu", "Remove") var _btn_clear: Callable = clear

@export_group("Monde")
## Taille du monde en cases (1 case = 1 mètre).
@export var world_size: Vector2i = Vector2i(140, 140)
@export var generate_on_start: bool = true
## Si activé, chaque partie a un monde différent.
@export var random_seed_on_start: bool = true
@export var world_seed: int = 12345
## Le joueur est placé ici. Laisser vide pour ne pas le déplacer.
@export var player: Node3D

@export_group("Bruits")
## Relief : décide eau / sable / herbe / roche.
@export var height_noise: FastNoiseLite
## Humidité : décide où poussent les forêts.
@export var moisture_noise: FastNoiseLite

@export_group("Altitudes (-1 à 1)")
@export_range(-1.0, 1.0, 0.01) var deep_water_level: float = -0.30
@export_range(-1.0, 1.0, 0.01) var water_level: float = -0.12
@export_range(-1.0, 1.0, 0.01) var sand_level: float = -0.05
@export_range(-1.0, 1.0, 0.01) var stone_level: float = 0.58
## Plus c'est haut, plus les bords du monde deviennent de l'océan.
@export_range(0.0, 3.0, 0.05) var island_falloff: float = 1.0
## Plus c'est haut, plus il y a de terres émergées.
@export_range(-1.0, 1.0, 0.01) var land_bias: float = 0.30

@export_group("Relief 3D")
## Hauteur d'une marche de terrain (en mètres).
@export var step_height: float = 0.25
## Écart d'altitude (bruit) entre deux marches. Plus petit = collines plus hautes.
@export_range(0.01, 0.5, 0.01) var terrace_size: float = 0.07
## Les marches de roche sont plus hautes (falaises).
@export var stone_step_multiplier: float = 2.0
## Plus haute marche que les personnages peuvent monter (en mètres).
@export var max_step: float = 0.55
## Hauteur de la surface de l'eau (en mètres).
@export var water_surface: float = -0.2

@export_group("Couleurs du sol")
@export var grass_color: Color = Color("5e9c44")
@export var grass_dark_color: Color = Color("4f8c3a")
@export var dirt_color: Color = Color("7a5a3c")
@export var sand_color: Color = Color("e0cc8a")
@export var stone_color: Color = Color("8e8c86")
@export var plaza_color: Color = Color("a09a8e")
@export var water_floor_color: Color = Color("c8b478")
@export var water_color: Color = Color(0.25, 0.55, 0.85, 0.72)

@export_group("Végétation")
@export_range(0.0, 1.0, 0.01) var forest_moisture: float = 0.05
@export_range(0.0, 1.0, 0.01) var forest_density: float = 0.30
@export_range(0.0, 1.0, 0.01) var scattered_tree_chance: float = 0.015
@export_range(0.0, 1.0, 0.01) var bush_chance: float = 0.02
@export_range(0.0, 1.0, 0.01) var rock_chance: float = 0.06
@export_range(0.0, 1.0, 0.01) var flower_chance: float = 0.05
@export_range(0.0, 1.0, 0.01) var grass_tuft_chance: float = 0.08
## Modèles voxel des décors (un est tiré au hasard pour chaque objet).
@export var oak_models: Array[PackedScene] = []
@export var pine_models: Array[PackedScene] = []
@export var bush_models: Array[PackedScene] = []
@export var rock_models: Array[PackedScene] = []
@export var flower_models: Array[PackedScene] = []
@export var grass_models: Array[PackedScene] = []

@export_group("Village de départ")
## Rayon (en cases) de la clairière dégagée autour du point de départ.
@export var spawn_clearing_radius: int = 11
## Rayon (en cases) de la place pavée autour du feu.
@export var plaza_radius: int = 4
@export var hut_scene: PackedScene
@export var campfire_scene: PackedScene
@export var barrel_scene: PackedScene
@export var crate_scene: PackedScene
@export var villager_scene: PackedScene
## Races possibles pour les habitants de départ.
@export var villager_races: Array[RaceData] = []
@export var villager_count: int = 6
## Établi (pour fabriquer les objets en fer) et râtelier d'armes du village.
@export var workbench_scene: PackedScene
@export var weapon_rack_scene: PackedScene
## Chance qu'un habitant commence avec une partie de l'équipement d'un métier.
@export_range(0.0, 1.0, 0.05) var villager_gear_chance: float = 0.85

@export_group("Objets à ramasser")
## Scène d'un objet posé au sol.
@export var pickup_scene: PackedScene
## Objets posés autour du feu au début de la partie.
@export var starting_loot: Array[ItemData] = []
## Équipements rares cachés dans la nature.
@export var wild_loot: Array[ItemData] = []
@export_range(0.0, 0.01, 0.0001) var wild_loot_chance: float = 0.0008
@export var wood_item: ItemData
@export var stone_item: ItemData
@export var iron_ore_item: ItemData
@export var leather_item: ItemData
@export var fiber_item: ItemData
## Chances par case (herbe près des forêts pour le bois, roche pour la pierre et le fer...).
@export_range(0.0, 0.05, 0.001) var wood_chance: float = 0.008
@export_range(0.0, 0.05, 0.001) var stone_chance: float = 0.012
@export_range(0.0, 0.05, 0.001) var iron_chance: float = 0.008
@export_range(0.0, 0.05, 0.001) var leather_chance: float = 0.003
@export_range(0.0, 0.05, 0.001) var fiber_chance: float = 0.004

@export_group("Monstres")
## Nombre de camps de monstres sur l'île.
@export var camp_count: int = 16
## Distance minimum (mètres) entre le village et un camp.
@export var camp_min_distance: float = 24.0
## Distance minimum entre deux camps.
@export var camp_spacing: float = 14.0
## Au-delà de cette distance du village, les monstres sont plus dangereux.
@export var danger_distance: float = 45.0
@export var monsters_per_camp := Vector2i(2, 4)
## Monstres des forêts, des plaines, de la roche, et monstres dangereux (loin du village).
@export var forest_enemies: Array[EnemyData] = []
@export var plains_enemies: Array[EnemyData] = []
@export var rock_enemies: Array[EnemyData] = []
@export var danger_enemies: Array[EnemyData] = []

# Types de sol
const DEEP := 0
const WATER := 1
const SAND := 2
const GRASS := 3
const STONE := 4
const PLAZA := 5
## Terre remuée (terrassement).
const DIRT := 6
# Types de décor
const D_NONE := 0
const D_OAK := 1
const D_PINE := 2
const D_BUSH := 3
const D_ROCK := 4
const D_FLOWERS := 5
const D_GRASS := 6

const CHUNK := 16
const SEA_FLOOR := -2.0
## Le grain des modèles voxel : la texture 16x16 couvre 16 voxels de 5 cm.
const GRAIN_SCALE := 1.0 / 0.8
const GRAIN := preload("res://assets/environment/voxel_grain.png")

var spawn_cell: Vector2i
var _rng := RandomNumberGenerator.new()
var _types := PackedByteArray()
var _heights := PackedFloat32Array()
var _flowers := PackedByteArray()
var _decor := PackedByteArray()
var _mesh_cache := {}
var _terrain_nodes := {}   # morceau -> MeshInstance3D
var _decor_nodes := {}     # morceau -> Node3D
var _terrain_mat: StandardMaterial3D
var _trunk_shape: CylinderShape3D
var _bush_shape: CylinderShape3D
var _rock_shape: BoxShape3D
## Les constructions du joueur (nœud « Build »).
var build: BuildGrid


func _ready() -> void:
	add_to_group("world")
	build = get_node_or_null("Build") as BuildGrid
	if Engine.is_editor_hint():
		return
	if generate_on_start:
		generate(randi() if random_seed_on_start else world_seed)


func _editor_preview() -> void:
	generate(world_seed)


func clear() -> void:
	for holder in [$Terrain, $Decor, $Village]:
		for child in holder.get_children():
			child.free()
	_terrain_nodes.clear()
	_decor_nodes.clear()
	if build:
		build.clear()


func generate(seed_value: int) -> void:
	world_seed = seed_value
	_ensure_noises()
	height_noise.seed = seed_value
	moisture_noise.seed = seed_value + 1
	_rng.seed = seed_value
	clear()

	var n := world_size.x * world_size.y
	_types.resize(n)
	_heights.resize(n)
	_flowers.resize(n)
	_decor.resize(n)
	_flowers.fill(0)
	_decor.fill(D_NONE)
	var center := Vector2(world_size) / 2.0

	for y in world_size.y:
		for x in world_size.x:
			var cell := Vector2i(x, y)
			var i := _idx(cell)
			var h := _height_at(cell, center)
			var m := moisture_noise.get_noise_2d(x, y)
			var t: int
			if h < deep_water_level:
				t = DEEP
			elif h < water_level:
				t = WATER
			elif h < sand_level:
				t = SAND
			elif h > stone_level:
				t = STONE
			else:
				t = GRASS
				if _rng.randf() < flower_chance:
					_flowers[i] = 1
			_types[i] = t
			_heights[i] = _terrain_height(t, h)
			var deco := _pick_decor(t, h, m)
			if (deco == D_OAK or deco == D_PINE) and x % 2 != 0:
				deco = D_NONE
			if deco == D_NONE and _flowers[i] == 1:
				deco = D_FLOWERS
			elif deco == D_NONE and t == GRASS and _rng.randf() < grass_tuft_chance:
				deco = D_GRASS
			_decor[i] = deco

	spawn_cell = _find_spawn(center)
	_make_clearing(spawn_cell)
	_build_terrain()
	_build_water()
	_build_decor()
	_place_player()
	if not Engine.is_editor_hint():
		_build_village()
		_scatter_loot()
		_spawn_camps()
	world_generated.emit(seed_value)


# ---------------------------------------------------------------- requêtes

func _idx(cell: Vector2i) -> int:
	return cell.y * world_size.x + cell.x


func _inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < world_size.x and cell.y < world_size.y


func _type(cell: Vector2i) -> int:
	return _types[_idx(cell)] if _inside(cell) else DEEP


func _h(cell: Vector2i) -> float:
	return _heights[_idx(cell)] if _inside(cell) else SEA_FLOOR


func cell_at(pos: Vector3) -> Vector2i:
	return Vector2i(floori(pos.x), floori(pos.z))


## Position 3D (au sol) du centre d'une case.
func cell_center(cell: Vector2i) -> Vector3:
	return Vector3(cell.x + 0.5, _h(cell), cell.y + 0.5)


## Hauteur du sol sous une position (terrain, ou dessus d'un bloc accessible depuis la hauteur `pos.y`).
func ground_height_at(pos: Vector3) -> float:
	return support_height(pos, pos.y)


## Surface sur laquelle on se tient dans la colonne de `pos`, pour quelqu'un dont les pieds sont à `feet`.
func support_height(pos: Vector3, feet: float) -> float:
	var cell := cell_at(pos)
	var t := _type(cell)
	var g := _h(cell)
	if (t == WATER or t == DEEP) and g < water_surface:
		g = water_surface
	if build:
		g = maxf(g, build.support(cell, feet + max_step))
	return g


func is_walkable(pos: Vector3) -> bool:
	var cell := cell_at(pos)
	var t := _type(cell)
	if t != WATER and t != DEEP:
		return true
	return build != null and build.support(cell, 1000.0) > water_surface


## Empêche d'entrer dans l'eau, de monter une marche trop haute ou de traverser un mur.
## Glisse le long de l'obstacle si possible.
func constrain_move(from: Vector3, to: Vector3) -> Vector3:
	if _can_step(from, to):
		return to
	var only_x := Vector3(to.x, to.y, from.z)
	if _can_step(from, only_x):
		return only_x
	var only_z := Vector3(from.x, to.y, to.z)
	if _can_step(from, only_z):
		return only_z
	return Vector3(from.x, to.y, from.z)


func _can_step(from: Vector3, to: Vector3) -> bool:
	var dir := Vector3(to.x - from.x, 0, to.z - from.z)
	var probe := to
	if dir.length_squared() > 0.000001:
		probe += dir.normalized() * 0.22
	var h_from := ground_height_at(from)
	for p in [probe, to]:
		var cell := cell_at(p)
		if not _inside(cell):
			return false
		if not step_ok(cell, h_from):
			return false
	return true


## Peut-on aller sur la case `cell` en partant d'une hauteur `h_from` ?
func step_ok(cell: Vector2i, h_from: float) -> bool:
	var hs := support_height(Vector3(cell.x + 0.5, 0, cell.y + 0.5), h_from)
	var t := _type(cell)
	if (t == WATER or t == DEEP) and hs <= water_surface + 0.01:
		return false
	if hs - h_from > max_step:
		return false
	if build and build.body_blocked(cell, hs):
		return false
	return true


## Chemin (liste de points) entre deux positions, en passant par les portes (A*, cases voisines).
func find_path(from: Vector3, to: Vector3, max_nodes := 2500) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var start := cell_at(from)
	var goal := cell_at(to)
	if start == goal:
		out.append(to)
		return out
	var open := [start]
	var came := {start: start}
	var g := {start: 0.0}
	var hgt := {start: ground_height_at(from)}
	var props := {}
	var visited := 0
	while not open.is_empty() and visited < max_nodes:
		var best := 0
		var best_f := INF
		for i in open.size():
			var c: Vector2i = open[i]
			var f: float = g[c] + Vector2(c - goal).length()
			if f < best_f:
				best_f = f
				best = i
		var cur: Vector2i = open[best]
		open.remove_at(best)
		visited += 1
		if cur == goal:
			var path := [cur]
			while path[0] != start:
				path.push_front(came[path[0]])
			for c in path.slice(1):
				out.append(Vector3(c.x + 0.5, hgt[c], c.y + 0.5))
			return out
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = cur + d
			if not _inside(n) or not step_ok(n, hgt[cur]):
				continue
			if n != goal and _prop_blocked(n, hgt[cur], props):
				continue
			var ng: float = g[cur] + 1.0
			if not g.has(n) or ng < g[n]:
				g[n] = ng
				came[n] = cur
				hgt[n] = support_height(Vector3(n.x + 0.5, 0, n.y + 0.5), hgt[cur])
				if not open.has(n):
					open.append(n)
	return out


## Vrai si un objet du décor (cabane, tonneau, feu...) occupe la case. Résultats mis en cache dans `cache`.
func _prop_blocked(cell: Vector2i, h: float, cache: Dictionary) -> bool:
	if cache.has(cell):
		return cache[cell]
	var shape := SphereShape3D.new()
	shape.radius = 0.3
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.transform = Transform3D(Basis(), Vector3(cell.x + 0.5, h + 0.6, cell.y + 0.5))
	q.collide_with_areas = false
	var blocked := false
	for hit in get_world_3d().direct_space_state.intersect_shape(q, 4):
		if hit.collider is StaticBody3D:
			blocked = true
			break
	cache[cell] = blocked
	return blocked


# ---------------------------------------------------------------- terrassement

func terrain_height(cell: Vector2i) -> float:
	return _h(cell)


func terrain_type(cell: Vector2i) -> int:
	return _type(cell)


func decor_at(cell: Vector2i) -> int:
	return _decor[_idx(cell)] if _inside(cell) else D_NONE


## Enlève le décor d'une case (arbre, rocher...). Renvoie son type (D_NONE s'il n'y avait rien).
func remove_decor(cell: Vector2i, refresh := true) -> int:
	if not _inside(cell):
		return D_NONE
	var i := _idx(cell)
	var k := _decor[i]
	_decor[i] = D_NONE
	_flowers[i] = 0
	if refresh and k != D_NONE:
		_build_decor_chunk(Vector2i(cell.x / CHUNK, cell.y / CHUNK))
	return k


## Change la hauteur d'une case. Le sol remué devient de la terre ; l'eau comblée devient de la terre.
func set_terrain_height(cell: Vector2i, h: float) -> void:
	if not _inside(cell):
		return
	var i := _idx(cell)
	var t := _types[i]
	if (t == WATER or t == DEEP) and h > water_surface:
		_types[i] = DIRT
	elif t == GRASS or t == PLAZA:
		_types[i] = DIRT
	_heights[i] = h
	if _decor[i] != D_NONE:
		_decor[i] = D_NONE
		_flowers[i] = 0


## Redessine le terrain (et les décors) autour de ces cases.
func refresh_cells(cells: Array, decor := true) -> void:
	var chunks := {}
	for c in cells:
		for dx in [-1, 0, 1]:
			for dz in [-1, 0, 1]:
				var n: Vector2i = c + Vector2i(dx, dz)
				if _inside(n):
					chunks[Vector2i(n.x / CHUNK, n.y / CHUNK)] = true
	for ch in chunks:
		_build_terrain_chunk(ch)
		if decor:
			_build_decor_chunk(ch)


# ---------------------------------------------------------------- génération

func _height_at(cell: Vector2i, center: Vector2) -> float:
	var h := height_noise.get_noise_2d(cell.x, cell.y)
	var d := (Vector2(cell) - center) / center
	var edge := maxf(absf(d.x), absf(d.y))
	return h - pow(edge, 4.0) * island_falloff + land_bias


func _terrain_height(t: int, h: float) -> float:
	match t:
		DEEP:
			return -1.5
		WATER:
			return -0.75
		SAND:
			return 0.0
		STONE:
			var top := step_height * (1.0 + floorf((stone_level - sand_level) / terrace_size))
			return top + step_height * stone_step_multiplier * (1.0 + floorf((h - stone_level) / terrace_size))
	return step_height * (1.0 + floorf((h - sand_level) / terrace_size))


func _pick_decor(t: int, h: float, m: float) -> int:
	if t == STONE:
		return D_ROCK if _rng.randf() < rock_chance else D_NONE
	if t == GRASS:
		if m > forest_moisture and _rng.randf() < forest_density:
			return D_PINE if h > 0.35 else D_OAK
		if _rng.randf() < scattered_tree_chance:
			return D_OAK
		if _rng.randf() < bush_chance:
			return D_BUSH
	elif t == SAND and _rng.randf() < rock_chance * 0.15:
		return D_ROCK
	return D_NONE


func _find_spawn(center: Vector2) -> Vector2i:
	# case d'herbe la plus proche du centre, entourée de terre ferme
	var c := Vector2i(center)
	for r in range(0, maxi(world_size.x, world_size.y) / 2):
		for y in range(c.y - r, c.y + r + 1):
			for x in range(c.x - r, c.x + r + 1):
				var cell := Vector2i(x, y)
				if _type(cell) == GRASS and _is_dry_area(cell, spawn_clearing_radius + 2):
					return cell
	return c


func _is_dry_area(cell: Vector2i, radius: int) -> bool:
	for y in range(-radius, radius + 1, 2):
		for x in range(-radius, radius + 1, 2):
			var t := _type(cell + Vector2i(x, y))
			if t == WATER or t == DEEP:
				return false
	return true


func _make_clearing(cell: Vector2i) -> void:
	var r := spawn_clearing_radius
	var base := _h(cell)
	var blend := 5
	for y in range(-r - blend, r + blend + 1):
		for x in range(-r - blend, r + blend + 1):
			var c := cell + Vector2i(x, y)
			if not _inside(c):
				continue
			var i := _idx(c)
			var t := _types[i]
			if t == WATER or t == DEEP:
				continue
			var d := Vector2(x, y).length()
			if d <= r + 2:
				_decor[i] = D_NONE if d <= r else _decor[i]
				_heights[i] = base
				if d <= plaza_radius + 0.5:
					_types[i] = PLAZA
					_decor[i] = D_NONE
					_flowers[i] = 0
				elif d <= r and t == STONE:
					_types[i] = GRASS
			elif d <= r + 2 + blend:
				# pente douce entre la clairière et le reste du terrain
				var k := (d - r - 2) / float(blend)
				_heights[i] = snappedf(lerpf(base, _heights[i], k), step_height)


# ---------------------------------------------------------------- sol 3D

func _top_color(cell: Vector2i) -> Color:
	var t := _type(cell)
	var v := (absi(hash(cell * 7 + Vector2i(world_seed % 991, 3))) % 1000) / 1000.0
	var c: Color
	match t:
		DEEP, WATER:
			c = water_floor_color.darkened(0.25 if t == DEEP else 0.0)
		SAND:
			c = sand_color
		STONE:
			c = stone_color
		PLAZA:
			c = plaza_color if (cell.x + cell.y) % 2 == 0 else plaza_color.darkened(0.08)
		DIRT:
			c = dirt_color.lightened(0.12)
		_:
			c = grass_color.lerp(grass_dark_color, v)
	return c.darkened(v * 0.07) if t != GRASS else c


func _side_color(cell: Vector2i) -> Color:
	match _type(cell):
		SAND, DEEP, WATER:
			return sand_color.darkened(0.1)
		STONE, PLAZA:
			return stone_color.darkened(0.08)
		DIRT:
			return dirt_color.darkened(0.05)
	return dirt_color


func _build_terrain() -> void:
	if _terrain_mat == null:
		_terrain_mat = StandardMaterial3D.new()
		_terrain_mat.vertex_color_use_as_albedo = true
		_terrain_mat.vertex_color_is_srgb = true
		_terrain_mat.albedo_texture = GRAIN
		_terrain_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
		_terrain_mat.roughness = 1.0
	for cy in ceili(world_size.y / float(CHUNK)):
		for cx in ceili(world_size.x / float(CHUNK)):
			_build_terrain_chunk(Vector2i(cx, cy))


func _build_terrain_chunk(ch: Vector2i) -> void:
	if _terrain_nodes.has(ch) and is_instance_valid(_terrain_nodes[ch]):
		_terrain_nodes[ch].queue_free()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for y in range(ch.y * CHUNK, mini((ch.y + 1) * CHUNK, world_size.y)):
		for x in range(ch.x * CHUNK, mini((ch.x + 1) * CHUNK, world_size.x)):
			_add_column(st, Vector2i(x, y))
	st.generate_tangents()
	var mi := MeshInstance3D.new()
	mi.name = "Sol_%d_%d" % [ch.x, ch.y]
	mi.mesh = st.commit()
	mi.material_override = _terrain_mat
	$Terrain.add_child(mi)
	_terrain_nodes[ch] = mi


func _add_column(st: SurfaceTool, cell: Vector2i) -> void:
	var h := _h(cell)
	var x0 := float(cell.x)
	var z0 := float(cell.y)
	var top := _top_color(cell)
	_quad(st, Vector3(x0, h, z0 + 1), Vector3(x0 + 1, h, z0 + 1), Vector3(x0 + 1, h, z0), Vector3(x0, h, z0),
		Vector3.UP, top, Vector2(x0, z0), true)
	var side := _side_color(cell)
	var t := _type(cell)
	var lip := top.darkened(0.12) if t == GRASS else side
	for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var nh := _h(cell + dir)
		if nh >= h:
			continue
		# bande d'herbe en haut du talus, terre en dessous
		var lip_bottom := maxf(nh, h - 0.12) if t == GRASS else nh
		_side(st, cell, dir, lip_bottom, h, lip)
		if lip_bottom > nh:
			_side(st, cell, dir, nh, lip_bottom, side)


func _side(st: SurfaceTool, cell: Vector2i, dir: Vector2i, y0: float, y1: float, color: Color) -> void:
	var x0 := float(cell.x)
	var z0 := float(cell.y)
	var n := Vector3(dir.x, 0, dir.y)
	# couleur un peu plus sombre sur les côtés pour marquer les blocs
	var c := color.darkened(0.05 + 0.04 * absf(dir.x))
	match dir:
		Vector2i(1, 0):
			_quad(st, Vector3(x0 + 1, y0, z0 + 1), Vector3(x0 + 1, y0, z0), Vector3(x0 + 1, y1, z0), Vector3(x0 + 1, y1, z0 + 1), n, c, Vector2(z0, y0), false)
		Vector2i(-1, 0):
			_quad(st, Vector3(x0, y0, z0), Vector3(x0, y0, z0 + 1), Vector3(x0, y1, z0 + 1), Vector3(x0, y1, z0), n, c, Vector2(z0, y0), false)
		Vector2i(0, 1):
			_quad(st, Vector3(x0, y0, z0 + 1), Vector3(x0 + 1, y0, z0 + 1), Vector3(x0 + 1, y1, z0 + 1), Vector3(x0, y1, z0 + 1), n, c, Vector2(x0, y0), false)
		_:
			_quad(st, Vector3(x0 + 1, y0, z0), Vector3(x0, y0, z0), Vector3(x0, y1, z0), Vector3(x0 + 1, y1, z0), n, c, Vector2(x0, y0), false)


## Quadrilatère a-b-c-d (sens anti-horaire vu de face).
func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3, color: Color, uv0: Vector2, is_top: bool) -> void:
	var verts := [a, b, c, d]
	var uvs := []
	for v in verts:
		var uv: Vector2
		if is_top:
			uv = Vector2(v.x, v.z)
		elif absf(n.x) > 0.5:
			uv = Vector2(v.z, -v.y)
		else:
			uv = Vector2(v.x, -v.y)
		uvs.append(uv * GRAIN_SCALE)
	for k in [0, 2, 1, 0, 3, 2]:
		st.set_normal(n)
		st.set_color(color)
		st.set_uv(uvs[k])
		st.add_vertex(verts[k])


func _build_water() -> void:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_opaque;
uniform vec4 water_color : source_color;
uniform sampler2D grain : filter_nearest, repeat_enable;
void fragment() {
	vec2 p = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xz;
	float g = texture(grain, p * 1.25 + vec2(TIME * 0.05, TIME * 0.03)).r;
	float g2 = texture(grain, p * 0.6 - vec2(TIME * 0.04, -TIME * 0.02)).r;
	float sparkle = step(0.985, g * g2 + 0.03 * sin(TIME * 2.0 + p.x));
	ALBEDO = water_color.rgb * (0.9 + 0.2 * g * g2) + vec3(sparkle * 0.5);
	ALPHA = water_color.a;
	ROUGHNESS = 0.15;
	SPECULAR = 0.6;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("water_color", water_color)
	mat.set_shader_parameter("grain", GRAIN)
	var plane := PlaneMesh.new()
	plane.size = Vector2(world_size) * 3.0
	var water := MeshInstance3D.new()
	water.name = "Eau"
	water.mesh = plane
	water.material_override = mat
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	water.position = Vector3(world_size.x / 2.0, water_surface, world_size.y / 2.0)
	$Terrain.add_child(water)
	# fond de l'océan autour de l'île
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = water_floor_color.darkened(0.35)
	floor_mat.albedo_texture = GRAIN
	floor_mat.uv1_scale = Vector3(world_size.x * 3.0, world_size.y * 3.0, 1) * GRAIN_SCALE
	floor_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(world_size) * 3.0
	var sea_floor := MeshInstance3D.new()
	sea_floor.name = "FondMarin"
	sea_floor.mesh = floor_mesh
	sea_floor.material_override = floor_mat
	sea_floor.position = Vector3(world_size.x / 2.0, SEA_FLOOR, world_size.y / 2.0)
	$Terrain.add_child(sea_floor)


# ---------------------------------------------------------------- décors 3D

func _models_for(kind: int) -> Array[PackedScene]:
	match kind:
		D_OAK:
			return oak_models
		D_PINE:
			return pine_models
		D_BUSH:
			return bush_models
		D_ROCK:
			return rock_models
		D_FLOWERS:
			return flower_models
		D_GRASS:
			return grass_models
	return []


## Maillage d'un modèle .glb de décor (avec sa position dans le modèle).
func _mesh_of(scene: PackedScene) -> Array:
	if _mesh_cache.has(scene):
		return _mesh_cache[scene]
	var inst := scene.instantiate() as Node3D
	var mi := inst.find_children("*", "MeshInstance3D", true, false)
	var result := []
	if not mi.is_empty():
		var m := mi[0] as MeshInstance3D
		var xf := Transform3D.IDENTITY
		var n: Node = m
		while n != inst and n is Node3D:
			xf = (n as Node3D).transform * xf
			n = n.get_parent()
		result = [m.mesh, xf]
	inst.free()
	_mesh_cache[scene] = result
	return result


func _build_decor() -> void:
	for cy in ceili(world_size.y / float(CHUNK)):
		for cx in ceili(world_size.x / float(CHUNK)):
			_build_decor_chunk(Vector2i(cx, cy))


func _build_decor_chunk(ch: Vector2i) -> void:
	if _decor_nodes.has(ch) and is_instance_valid(_decor_nodes[ch]):
		_decor_nodes[ch].queue_free()
	if _trunk_shape == null:
		_trunk_shape = CylinderShape3D.new()
		_trunk_shape.radius = 0.35
		_trunk_shape.height = 3.0
		_bush_shape = CylinderShape3D.new()
		_bush_shape.radius = 0.5
		_bush_shape.height = 1.0
		_rock_shape = BoxShape3D.new()
		_rock_shape.size = Vector3(1.0, 1.0, 0.9)
	var holder := Node3D.new()
	holder.name = "Decor_%d_%d" % [ch.x, ch.y]
	var obstacles := StaticBody3D.new()
	holder.add_child(obstacles)
	var groups := {}  # scène -> transforms
	for y in range(ch.y * CHUNK, mini((ch.y + 1) * CHUNK, world_size.y)):
		for x in range(ch.x * CHUNK, mini((ch.x + 1) * CHUNK, world_size.x)):
			var cell := Vector2i(x, y)
			var kind := _decor[_idx(cell)]
			if kind == D_NONE:
				continue
			var models := _models_for(kind)
			if models.is_empty():
				continue
			# hasard propre à la case : le décor ne change pas quand on redessine le morceau
			var drng := RandomNumberGenerator.new()
			drng.seed = hash(Vector3i(x, y, world_seed))
			var scene: PackedScene = models[drng.randi() % models.size()]
			var s := 1.0
			var jitter := 0.2
			match kind:
				D_OAK, D_PINE:
					s = drng.randf_range(0.85, 1.2)
				D_FLOWERS, D_GRASS:
					s = drng.randf_range(0.8, 1.3)
					jitter = 0.3
				D_ROCK:
					s = drng.randf_range(0.8, 1.3)
			var pos := cell_center(cell) + Vector3(drng.randf_range(-jitter, jitter), 0, drng.randf_range(-jitter, jitter))
			var basis := Basis(Vector3.UP, drng.randi_range(0, 3) * PI * 0.5).scaled(Vector3.ONE * s)
			if not groups.has(scene):
				groups[scene] = []
			groups[scene].append(Transform3D(basis, pos))
			var shape: Shape3D = null
			var shape_y := 0.0
			match kind:
				D_OAK, D_PINE:
					shape = _trunk_shape
					shape_y = 1.5
				D_BUSH:
					shape = _bush_shape
					shape_y = 0.5
				D_ROCK:
					shape = _rock_shape
					shape_y = 0.5
			if shape:
				var cs := CollisionShape3D.new()
				cs.shape = shape
				cs.position = pos + Vector3(0, shape_y, 0)
				obstacles.add_child(cs)
	for scene in groups:
		var info := _mesh_of(scene)
		if info.is_empty():
			continue
		var list: Array = groups[scene]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = info[0]
		mm.instance_count = list.size()
		for i in list.size():
			mm.set_instance_transform(i, (list[i] as Transform3D) * (info[1] as Transform3D))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		holder.add_child(mmi)
	$Decor.add_child(holder)
	_decor_nodes[ch] = holder


# ---------------------------------------------------------------- village

func _place_player() -> void:
	if player == null:
		return
	player.global_position = cell_center(spawn_cell) + Vector3(0, 0, 5)
	if player.has_method("snap_camera"):
		player.snap_camera()


func _spawn(scene: PackedScene, offset: Vector2, extra := {}) -> Node3D:
	if scene == null:
		return null
	var n := scene.instantiate() as Node3D
	for k in extra:
		n.set(k, extra[k])
	$Village.add_child(n)
	var origin := cell_center(spawn_cell)
	n.global_position = Vector3(origin.x + offset.x, origin.y, origin.z + offset.y)
	return n


## Tourne un objet pour que sa face avant (+Z) regarde le feu.
func _face_center(n: Node3D) -> void:
	if n == null:
		return
	var to := cell_center(spawn_cell) - n.global_position
	n.rotation.y = snappedf(atan2(to.x, to.z), PI / 8.0)


func _build_village() -> void:
	_spawn(campfire_scene, Vector2(0, 0))
	_face_center(_spawn(hut_scene, Vector2(-7.0, -3.5)))
	_face_center(_spawn(hut_scene, Vector2(7.0, -4.0)))
	_face_center(_spawn(hut_scene, Vector2(0.5, -8.5)))
	_spawn(barrel_scene, Vector2(-3.8, -5.8))
	_spawn(barrel_scene, Vector2(-3.0, -6.3))
	_spawn(barrel_scene, Vector2(-3.4, -5.1))
	_spawn(crate_scene, Vector2(3.6, -6.4)).rotation.y = 0.3
	_spawn(crate_scene, Vector2(9.8, -1.2))
	_spawn(crate_scene, Vector2(4.4, -6.9)).rotation.y = -0.2
	var bench := _spawn(workbench_scene, Vector2(-8.5, 3.5))
	_face_center(bench)
	_face_center(_spawn(weapon_rack_scene, Vector2(9.0, 2.5)))
	# objets posés autour du feu
	for i in starting_loot.size():
		var a := PI * 0.15 + PI * 0.7 * float(i) / maxf(1.0, starting_loot.size() - 1.0)
		var off := Vector2.from_angle(a) * (2.6 + (i % 2) * 1.0)
		var origin := cell_center(spawn_cell)
		spawn_pickup(starting_loot[i], Vector3(origin.x + off.x, origin.y, origin.z + off.y))
	if villager_scene == null or villager_races.is_empty():
		return
	var pool := villager_races.duplicate()
	pool.shuffle()
	var kits := VILLAGER_KITS.duplicate()
	kits.shuffle()
	for i in villager_count:
		var race: RaceData = pool[i % pool.size()]
		var angle := TAU * float(i) / float(villager_count) + _rng.randf() * 0.4
		var off := Vector2.from_angle(angle) * _rng.randf_range(2.5, 5.5)
		var v := _spawn(villager_scene, off, {"race": race})
		if v and _rng.randf() < villager_gear_chance:
			_give_kit(v, kits[i % kits.size()])


## Tenues de départ des habitants (identifiants d'objets de data/items/).
const VILLAGER_KITS := [
	["spear", "iron_helmet", "shield_wood", "leather_armor", "leather_pants"],
	["staff", "mage_hat", "mage_robe", "cape_blue"],
	["axe", "horned_helmet", "leather_armor", "leather_bracers", "iron_greaves"],
	["sword_iron", "shield_iron", "iron_armor", "iron_helmet", "iron_gauntlets", "iron_greaves", "cape_red"],
	["dagger", "leather_cap", "leather_armor", "leather_pants", "leather_bracers", "cape_red"],
	["war_hammer", "iron_armor", "iron_gauntlets", "leather_pants"],
]


## Équipe un habitant avec une partie (au moins la moitié) d'une tenue.
func _give_kit(villager: Node, kit: Array) -> void:
	var eq := villager.get_node_or_null("Equipment") as CharacterEquipment
	if eq == null:
		return
	var n := _rng.randi_range(ceili(kit.size() / 2.0), kit.size())
	for i in n:
		var item := Items.get_item(kit[i]) as ItemData
		if item:
			eq.equip(item)


## Pose un objet au sol (il flotte et se ramasse en marchant dessus).
func spawn_pickup(item: ItemData, pos: Vector3, amount: int = 1) -> ItemPickup:
	if pickup_scene == null or item == null:
		return null
	var p := pickup_scene.instantiate() as ItemPickup
	p.item = item
	p.count = amount
	$Village.add_child(p)
	p.global_position = Vector3(pos.x, ground_height_at(pos), pos.z)
	return p


## Place les camps de monstres, loin du village.
func _spawn_camps() -> void:
	var crng := RandomNumberGenerator.new()
	crng.seed = world_seed + 555
	var origin := cell_center(spawn_cell)
	var camps: Array[Vector3] = []
	var tries := 0
	while camps.size() < camp_count and tries < 4000:
		tries += 1
		var cell := Vector2i(crng.randi_range(2, world_size.x - 3), crng.randi_range(2, world_size.y - 3))
		var t := _type(cell)
		if t != GRASS and t != STONE:
			continue
		var pos := cell_center(cell)
		var d := Vector2(pos.x - origin.x, pos.z - origin.z).length()
		if d < camp_min_distance:
			continue
		var ok := true
		for c in camps:
			if c.distance_to(pos) < camp_spacing:
				ok = false
				break
		if not ok or not _is_dry_area(cell, 2):
			continue
		var pool: Array[EnemyData]
		if d > danger_distance and not danger_enemies.is_empty() and crng.randf() < 0.45:
			pool = danger_enemies
		elif t == STONE:
			pool = rock_enemies
		elif moisture_noise.get_noise_2d(cell.x, cell.y) > forest_moisture:
			pool = forest_enemies
		else:
			pool = plains_enemies
		if pool.is_empty():
			continue
		var camp := EnemyCamp.new()
		camp.name = "Camp_%d" % camps.size()
		camp.enemy_types = [pool[crng.randi() % pool.size()]]
		camp.count = crng.randi_range(monsters_per_camp.x, monsters_per_camp.y)
		$Village.add_child(camp)
		camp.global_position = pos
		camps.append(pos)


## Répartit les matériaux et quelques équipements rares sur l'île.
func _scatter_loot() -> void:
	var lrng := RandomNumberGenerator.new()
	lrng.seed = world_seed + 99
	for y in world_size.y:
		for x in world_size.x:
			var cell := Vector2i(x, y)
			var i := _idx(cell)
			var d := _decor[i]
			if d == D_OAK or d == D_PINE or d == D_BUSH or d == D_ROCK:
				continue
			if Vector2(cell - spawn_cell).length() < plaza_radius + 1:
				continue
			var t := _types[i]
			var item: ItemData = null
			var amount := 1
			var r := lrng.randf()
			match t:
				GRASS:
					var m := moisture_noise.get_noise_2d(x, y)
					if m > forest_moisture and r < wood_chance:
						item = wood_item
						amount = lrng.randi_range(1, 3)
					elif r < fiber_chance:
						item = fiber_item
						amount = lrng.randi_range(1, 3)
					elif r < fiber_chance + leather_chance:
						item = leather_item
					elif r < fiber_chance + leather_chance + wild_loot_chance and not wild_loot.is_empty():
						item = wild_loot[lrng.randi() % wild_loot.size()]
				STONE:
					if r < iron_chance:
						item = iron_ore_item
						amount = lrng.randi_range(1, 2)
					elif r < iron_chance + stone_chance:
						item = stone_item
						amount = lrng.randi_range(1, 3)
				SAND:
					if r < stone_chance * 0.4:
						item = stone_item
			if item:
				spawn_pickup(item, cell_center(cell), amount)


func _ensure_noises() -> void:
	if height_noise == null:
		height_noise = FastNoiseLite.new()
		height_noise.frequency = 0.025
	if moisture_noise == null:
		moisture_noise = FastNoiseLite.new()
		moisture_noise.frequency = 0.04
