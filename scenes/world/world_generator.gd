@tool
class_name WorldGenerator
extends Node2D
## Génère le monde (île) à partir de bruits, puis installe le village de départ.
## Tous les réglages sont dans l'Inspecteur. Le bouton « Générer un aperçu »
## affiche le terrain directement dans l'éditeur (sans le village).

signal world_generated(seed_used: int)

@export_tool_button("Générer un aperçu", "Reload") var _btn_generate: Callable = _editor_preview
@export_tool_button("Effacer l'aperçu", "Remove") var _btn_clear: Callable = clear

@export_group("Monde")
## Taille du monde en tuiles (1 tuile = 32 pixels).
@export var world_size: Vector2i = Vector2i(140, 140)
@export var generate_on_start: bool = true
## Si activé, chaque partie a un monde différent.
@export var random_seed_on_start: bool = true
@export var world_seed: int = 12345
## Le joueur est placé ici. Laisser vide pour ne pas le déplacer.
@export var player: Node2D

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

@export_group("Végétation")
@export_range(0.0, 1.0, 0.01) var forest_moisture: float = 0.05
@export_range(0.0, 1.0, 0.01) var forest_density: float = 0.30
@export_range(0.0, 1.0, 0.01) var scattered_tree_chance: float = 0.015
@export_range(0.0, 1.0, 0.01) var bush_chance: float = 0.02
@export_range(0.0, 1.0, 0.01) var rock_chance: float = 0.06
@export_range(0.0, 1.0, 0.01) var flower_chance: float = 0.05

@export_group("Village de départ")
## Rayon (en tuiles) de la clairière dégagée autour du point de départ.
@export var spawn_clearing_radius: int = 8
## Rayon (en tuiles) de la place pavée autour du feu.
@export var plaza_radius: int = 3
@export var hut_scene: PackedScene
@export var campfire_scene: PackedScene
@export var barrel_scene: PackedScene
@export var crate_scene: PackedScene
@export var villager_scene: PackedScene
## Races possibles pour les habitants de départ.
@export var villager_races: Array[RaceData] = []
@export var villager_count: int = 6

# Coordonnées des tuiles (source 0 = terrain, source 1 = objets)
const T_GRASS := [Vector2i(0, 0), Vector2i(1, 0)]
const T_FLOWERS := Vector2i(2, 0)
const T_DIRT := Vector2i(3, 0)
const T_SAND := Vector2i(4, 0)
const T_WATER := Vector2i(5, 0)
const T_DEEP_WATER := Vector2i(6, 0)
const T_STONE := Vector2i(7, 0)
const T_BRICKS := Vector2i(8, 0)
const O_OAK := Vector2i(0, 0)
const O_PINE := Vector2i(3, 0)
const O_BUSH := Vector2i(5, 0)
const O_ROCK := Vector2i(5, 1)
const SRC_TERRAIN := 0
const SRC_OBJECTS := 1
const NONE := Vector2i(-1, -1)

var spawn_cell: Vector2i
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if generate_on_start:
		generate(randi() if random_seed_on_start else world_seed)


func _editor_preview() -> void:
	generate(world_seed)


func clear() -> void:
	$Sol.clear()
	$Decor.clear()
	for layer in $SolRendu.get_children():
		layer.clear()
	for child in $Village.get_children():
		child.free()


func generate(seed_value: int) -> void:
	world_seed = seed_value
	_ensure_noises()
	height_noise.seed = seed_value
	moisture_noise.seed = seed_value + 1
	_rng.seed = seed_value
	clear()

	var ground: TileMapLayer = $Sol
	var decor: TileMapLayer = $Decor
	var center := Vector2(world_size) / 2.0

	for y in world_size.y:
		for x in world_size.x:
			var cell := Vector2i(x, y)
			var h := _height_at(cell, center)
			var m := moisture_noise.get_noise_2d(x, y)
			var tile: Vector2i
			if h < deep_water_level:
				tile = T_DEEP_WATER
			elif h < water_level:
				tile = T_WATER
			elif h < sand_level:
				tile = T_SAND
			elif h > stone_level:
				tile = T_STONE
			else:
				tile = T_GRASS[_rng.randi() % T_GRASS.size()]
				if _rng.randf() < flower_chance:
					tile = T_FLOWERS
			ground.set_cell(cell, SRC_TERRAIN, tile)

			var deco := _pick_decor(tile, h, m)
			if deco != NONE and x % 2 == 0 and (deco == O_OAK or deco == O_PINE):
				decor.set_cell(cell, SRC_OBJECTS, deco)
			elif deco != NONE and deco != O_OAK and deco != O_PINE:
				decor.set_cell(cell, SRC_OBJECTS, deco)

	spawn_cell = _find_spawn(center)
	_make_clearing(spawn_cell)
	_paint_ground()
	_place_player()
	if not Engine.is_editor_hint():
		_build_village()
	world_generated.emit(seed_value)


## Niveau de terrain d'une case : 0 eau profonde, 1 eau, 2 sable, 3 herbe, 4 roche, 5 place pavée.
func _level(cell: Vector2i) -> int:
	var t: Vector2i = $Sol.get_cell_atlas_coords(cell)
	match t:
		T_DEEP_WATER, NONE:
			return 0
		T_WATER:
			return 1
		T_SAND:
			return 2
		T_STONE:
			return 4
		T_BRICKS:
			return 5
	return 3


## Dessine le sol visible avec des transitions arrondies (grille décalée d'une demi-tuile).
## Chaque couche (SolRendu/…) utilise 16 formes x 3 variantes de assets/tiles/terrain_dual.png.
func _paint_ground() -> void:
	var layers := $SolRendu.get_children()
	var levels := {}
	for y in range(-1, world_size.y + 1):
		for x in range(-1, world_size.x + 1):
			levels[Vector2i(x, y)] = _level(Vector2i(x, y))
	for j in range(0, world_size.y + 1):
		for i in range(0, world_size.x + 1):
			var c := [levels[Vector2i(i - 1, j - 1)], levels[Vector2i(i, j - 1)], levels[Vector2i(i - 1, j)], levels[Vector2i(i, j)]]
			var h := absi(hash(Vector2i(i, j) + Vector2i(world_seed % 997, 0)))
			for li in layers.size():
				var idx := 0
				for k in 4:
					var on := false
					match li:
						0: on = true
						1: on = c[k] >= 1
						2: on = c[k] >= 2
						3: on = c[k] >= 3
						4: on = c[k] == 4
						5: on = c[k] == 5
					if on:
						idx |= 8 >> k
				if idx == 0:
					continue
				var variant := h % 2
				if li == 3 and (h >> 3) % 100 < int(flower_chance * 100.0):
					variant = 2
				(layers[li] as TileMapLayer).set_cell(Vector2i(i, j), 0, Vector2i(idx * 3 + variant, li))


func _height_at(cell: Vector2i, center: Vector2) -> float:
	var h := height_noise.get_noise_2d(cell.x, cell.y)
	var d := (Vector2(cell) - center) / center
	var edge := maxf(absf(d.x), absf(d.y))
	return h - pow(edge, 4.0) * island_falloff + land_bias


func _pick_decor(tile: Vector2i, h: float, m: float) -> Vector2i:
	if tile == T_STONE:
		return O_ROCK if _rng.randf() < rock_chance else NONE
	if tile in T_GRASS or tile == T_DIRT or tile == T_FLOWERS:
		if m > forest_moisture and _rng.randf() < forest_density:
			return O_PINE if h > 0.35 else O_OAK
		if _rng.randf() < scattered_tree_chance:
			return O_OAK
		if _rng.randf() < bush_chance:
			return O_BUSH
	return NONE


func _find_spawn(center: Vector2) -> Vector2i:
	# case d'herbe la plus proche du centre, entourée de terre ferme
	var c := Vector2i(center)
	for r in range(0, maxi(world_size.x, world_size.y) / 2):
		for y in range(c.y - r, c.y + r + 1):
			for x in range(c.x - r, c.x + r + 1):
				var cell := Vector2i(x, y)
				if $Sol.get_cell_atlas_coords(cell) in T_GRASS and _is_dry_area(cell, spawn_clearing_radius):
					return cell
	return c


func _is_dry_area(cell: Vector2i, radius: int) -> bool:
	for y in range(-radius, radius + 1, 2):
		for x in range(-radius, radius + 1, 2):
			var t: Vector2i = $Sol.get_cell_atlas_coords(cell + Vector2i(x, y))
			if t == T_WATER or t == T_DEEP_WATER or t == NONE:
				return false
	return true


func _make_clearing(cell: Vector2i) -> void:
	var r := spawn_clearing_radius
	for y in range(-r - 2, r + 3):
		for x in range(-r - 2, r + 3):
			var d := Vector2(x, y).length()
			if d <= r + 2:
				$Decor.erase_cell(cell + Vector2i(x, y))
			if d <= plaza_radius + 0.5:
				$Sol.set_cell(cell + Vector2i(x, y), SRC_TERRAIN, T_BRICKS)
			elif d <= r and $Sol.get_cell_atlas_coords(cell + Vector2i(x, y)) == T_STONE:
				$Sol.set_cell(cell + Vector2i(x, y), SRC_TERRAIN, T_GRASS[0])


func _cell_pos(cell: Vector2i) -> Vector2:
	return $Sol.to_global($Sol.map_to_local(cell))


func _place_player() -> void:
	if player == null:
		return
	player.global_position = _cell_pos(spawn_cell + Vector2i(0, 4))
	var cam := player.get_node_or_null("Camera") as Camera2D
	if cam:
		var tile_size: Vector2i = $Sol.tile_set.tile_size
		cam.limit_left = 0
		cam.limit_top = 0
		cam.limit_right = world_size.x * tile_size.x
		cam.limit_bottom = world_size.y * tile_size.y
		cam.reset_smoothing()


func _spawn(scene: PackedScene, cell_offset: Vector2, extra := {}) -> Node2D:
	if scene == null:
		return null
	var n := scene.instantiate() as Node2D
	for k in extra:
		n.set(k, extra[k])
	$Village.add_child(n)
	n.global_position = _cell_pos(spawn_cell) + cell_offset * 32.0
	return n


func _build_village() -> void:
	_spawn(campfire_scene, Vector2(0, 0.3))
	_spawn(hut_scene, Vector2(-5, -2.5))
	_spawn(hut_scene, Vector2(4.5, -3))
	_spawn(barrel_scene, Vector2(-2.6, -2.2))
	_spawn(barrel_scene, Vector2(-2.0, -1.8))
	_spawn(crate_scene, Vector2(2.2, -2.0))
	_spawn(crate_scene, Vector2(6.8, -1.6))
	if villager_scene == null or villager_races.is_empty():
		return
	var pool := villager_races.duplicate()
	pool.shuffle()
	for i in villager_count:
		var race: RaceData = pool[i % pool.size()]
		var angle := TAU * float(i) / float(villager_count) + _rng.randf() * 0.4
		var off := Vector2.from_angle(angle) * _rng.randf_range(2.5, 5.0)
		_spawn(villager_scene, off, {"race": race})


func _ensure_noises() -> void:
	if height_noise == null:
		height_noise = FastNoiseLite.new()
		height_noise.frequency = 0.025
	if moisture_noise == null:
		moisture_noise = FastNoiseLite.new()
		moisture_noise.frequency = 0.04
