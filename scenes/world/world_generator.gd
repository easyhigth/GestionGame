@tool
class_name WorldGenerator
extends Node3D
## Génère le monde ouvert 3D voxel à partir de bruits, puis installe le village de départ.
## Le monde est découpé en zones (régions nommées : prairie, forêt profonde, désert...) décrites
## par les fichiers de data/regions/. Le terrain est calculé et affiché par morceaux de 16 m
## autour du héros : seuls les morceaux proches existent en 3D.
## Tous les réglages sont dans l'Inspecteur. Le bouton « Générer un aperçu »
## affiche le terrain autour du centre directement dans l'éditeur (sans le village).
## 1 case = 1 mètre. Le sol est fait de colonnes de blocs, les décors sont des modèles voxel (.glb).

signal world_generated(seed_used: int)
## Le héros entre dans une autre zone.
signal zone_entered(zone: Dictionary)
## Un obélisque de téléportation vient d'être activé.
signal obelisk_activated(zone: Dictionary)

@export_tool_button("Générer un aperçu", "Reload") var _btn_generate: Callable = _editor_preview
@export_tool_button("Effacer l'aperçu", "Remove") var _btn_clear: Callable = clear

@export_group("Monde")
## Taille du monde en cases (1 case = 1 m).
@export var world_size: Vector2i = Vector2i(1536, 1536)
## Taille (en mètres) d'une zone : le monde est découpé en zones d'environ cette taille.
@export var zone_size: int = 128
## Distance d'affichage autour du héros (en morceaux de 16 m).
@export_range(2.0, 10.0, 0.5) var view_distance: float = 4.5
## Distance au-delà de laquelle la petite végétation (fleurs, herbes, fougères) n'est plus dessinée (0 : toujours).
var small_decor_range := 60.0
## Largeur (en mètres) des transitions entre deux régions.
@export var region_blend: float = 10.0
## Dossier des types de régions.
@export_dir var regions_dir: String = "res://data/regions/"
@export var generate_on_start: bool = true
## Une nouvelle île à chaque partie (sinon, `world_seed` est utilisé).
@export var random_seed_on_start: bool = true
@export var world_seed: int = 12345
## Le joueur, placé au village après la génération.
@export var player: Node3D

@export_group("Bruits")
## Bruit du relief.
@export var height_noise: FastNoiseLite
## Bruit de l'humidité (forêts).
@export var moisture_noise: FastNoiseLite

@export_group("Altitudes (-1 à 1)")
@export_range(-1.0, 1.0, 0.01) var deep_water_level: float = -0.30
@export_range(-1.0, 1.0, 0.01) var water_level: float = -0.12
@export_range(-1.0, 1.0, 0.01) var sand_level: float = -0.05
@export_range(-1.0, 1.0, 0.01) var stone_level: float = 0.58
## Force de l'effet « île » (les bords du monde descendent dans la mer).
@export_range(0.0, 3.0, 0.05) var island_falloff: float = 1.0
## Monte ou descend tout le terrain (plus = plus de terre).
@export_range(-1.0, 1.0, 0.01) var land_bias: float = 0.30

@export_group("Relief 3D")
## Hauteur d'une marche de terrain (mètres).
@export var step_height: float = 0.25
## Écart d'altitude (bruit) entre deux marches : plus petit = plus de marches.
@export_range(0.01, 0.5, 0.01) var terrace_size: float = 0.07
## Les rochers montent plus vite (falaises).
@export var stone_step_multiplier: float = 2.0
## Hauteur de marche maximale franchissable à pied (mètres).
@export var max_step: float = 0.55
## Hauteur de la surface de l'eau.
@export var water_surface: float = -0.2

@export_group("Couleurs du sol")
## Couleurs par défaut (chaque région a les siennes dans data/regions/).
@export var grass_color: Color = Color("5e9c44")
@export var grass_dark_color: Color = Color("4f8c3a")
@export var dirt_color: Color = Color("7a5a3c")
@export var sand_color: Color = Color("e0cc8a")
@export var stone_color: Color = Color("8e8c86")
@export var plaza_color: Color = Color("a09a8e")
@export var water_floor_color: Color = Color("c8b478")
@export var water_color: Color = Color(0.25, 0.55, 0.85, 0.72)

@export_group("Végétation")
## Au-dessus de cette humidité, l'herbe devient forêt.
@export_range(-1.0, 1.0, 0.01) var forest_moisture: float = 0.05
## Modèles par défaut (si une région n'en donne pas).
@export var oak_models: Array[PackedScene] = []
@export var pine_models: Array[PackedScene] = []
@export var bush_models: Array[PackedScene] = []
@export var rock_models: Array[PackedScene] = []
@export var flower_models: Array[PackedScene] = []
@export var grass_models: Array[PackedScene] = []

@export_group("Village de départ")
## Rayon (en cases) de la clairière autour du village.
@export var spawn_clearing_radius: int = 11
## Rayon de la place pavée.
@export var plaza_radius: int = 4
@export var hut_scene: PackedScene
@export var campfire_scene: PackedScene
@export var barrel_scene: PackedScene
@export var crate_scene: PackedScene
@export var villager_scene: PackedScene
## Races possibles des habitants.
@export var villager_races: Array[RaceData] = []
@export var villager_count: int = 6
@export var workbench_scene: PackedScene
@export var weapon_rack_scene: PackedScene
## Chance qu'un habitant porte un équipement au départ.
@export_range(0.0, 1.0, 0.05) var villager_gear_chance: float = 0.85

@export_group("Objets à ramasser")
@export var pickup_scene: PackedScene
## Objets posés autour du feu au départ.
@export var starting_loot: Array[ItemData] = []
## Équipements rares qu'on peut trouver dans la nature.
@export var wild_loot: Array[ItemData] = []
@export_range(0.0, 0.01, 0.0001) var wild_loot_chance: float = 0.0006
@export var wood_item: ItemData
@export var stone_item: ItemData
@export var iron_ore_item: ItemData
@export var leather_item: ItemData
@export var fiber_item: ItemData

@export_group("Monstres")
## Pas de camp de monstres plus près que ça du village (mètres).
@export var camp_min_distance: float = 26.0
## Écart minimal entre deux camps (mètres).
@export var camp_spacing: float = 14.0
@export var monsters_per_camp := Vector2i(2, 4)
## Anciens réglages (monde sans régions) : utilisés si aucune région n'est trouvée.
@export var forest_enemies: Array[EnemyData] = []
@export var plains_enemies: Array[EnemyData] = []
@export var rock_enemies: Array[EnemyData] = []
@export var danger_enemies: Array[EnemyData] = []

@export_group("Lieux")
## Obélisque de téléportation (un par zone).
@export var obelisk_model: PackedScene = preload("res://scenes/decor/obelisk.tscn")
## Entrée de donjon (une par zone, hors zone de départ).
@export var dungeon_gate_model: PackedScene = preload("res://scenes/decor/dungeon_gate.tscn")

# types de sol
const DEEP := 0
const WATER := 1
const SAND := 2
const GRASS := 3
const STONE := 4
const PLAZA := 5
## Sol remué par le joueur (terrassement).
const DIRT := 6
## Terre labourée (houe) : on peut y semer.
const FARM := 7

# décors
const D_NONE := 0
## Part des carrés de 8 m sans arbres (clairières).
const CLEARING_CHANCE := 0.15
const D_OAK := 1     # arbre (modèle choisi dans la région)
const D_PINE := 2    # arbre (ancien type)
const D_BUSH := 3
const D_ROCK := 4
const D_FLOWERS := 5 # petite plante (modèle choisi dans la région)
const D_GRASS := 6
## Filons de minerai (dans la roche) : il faut une pioche pour le fer, une pioche en fer pour l'or.
const D_IRON := 7
const D_GOLD := 8
const IRON_CHANCE := 0.018
const GOLD_CHANCE := 0.004

const CHUNK := 16
## Masque de l'eau (une case = un pixel : blanc = lac ou mer) : le plan d'eau et le fond marin ne se montrent
## qu'au-dessus des vraies cases d'eau. Sans lui, creuser sous le niveau de la mer remplissait le trou d'eau.
var _water_mask: Image
var _water_mask_tex: ImageTexture
var _water_mask_dirty := false
## Sous cette altitude, on est dans un donjon (le sol est celui de `dungeon_grid`).
const UNDERGROUND := -40.0
const SEA_FLOOR := -2.0
## Rayon (m) autour du héros dévoilé sur la carte.
const REVEAL_RADIUS := 26
## Amplitude des crêtes de montagne par région (0 : pas de grands sommets).
const PEAKS := {"montagnes": 1.3, "toundra": 0.7, "volcan": 0.9}
const GRAIN_SCALE := 1.0 / 0.8
const GRAIN := preload("res://assets/environment/voxel_grain.png")

var spawn_cell: Vector2i
## Drapeau du royaume : là où le joueur le plante, c'est le centre de son camp (habitants, raids, carte,
## marchand, quêtes...). Pas de drapeau planté : pas de camp, donc pas de raids. Voir has_home / home_center.
const FLAG_ID := "drapeau_royaume"
signal home_changed
var home_cell := Vector2i(-1, -1)
## Dernier endroit où le drapeau était planté (les habitants y restent si on l'arrache).
var _last_home := Vector2i(-1, -1)
## Zones du monde : {id, type (RegionData), name, site, level, obelisk, gate, discovered, obelisk_on}
var zones: Array = []
var region_types: Array[RegionData] = []
## Carte du monde (1 pixel = 1 case), dévoilée au fil de l'exploration.
var map_image: Image
var map_texture: ImageTexture
var current_zone := -1
var build: BuildGrid
## Grille du donjon en cours (null hors donjon).
var dungeon_grid: BuildGrid

var _rng := RandomNumberGenerator.new()
var _types := PackedByteArray()
var _heights := PackedFloat32Array()
var _decor := PackedByteArray()
var _zone := PackedByteArray()    # zone principale de chaque case
var _zone2 := PackedByteArray()   # zone voisine (transition)
var _blend := PackedByteArray()   # part de la zone voisine (0 à 127 = 0 à 50 %)
var _chunks := Vector2i.ZERO
var _chunk_ready := PackedByteArray()
var _revealed := PackedByteArray()
var _map_dirty := false
var _map_timer := 0.0
var _last_reveal := Vector3.INF
var _warp_noise: FastNoiseLite
var _ridge_noise: FastNoiseLite
var _mesh_cache := {}
var _terrain_nodes := {}   # morceau -> MeshInstance3D
var _decor_nodes := {}     # morceau -> Node3D
var _content_nodes := {}   # morceau -> Node3D (camps, objets, lieux)
var _taken := {}           # objets déjà ramassés (case -> true)
var _camp_cells: Array[Vector2i] = []
var _terrain_mat: ShaderMaterial
var _liquid_mat: StandardMaterial3D
var _lava_mat: StandardMaterial3D
var _trunk_shape: CylinderShape3D
var _bush_shape: CylinderShape3D
var _rock_shape: BoxShape3D
var _stream_timer := 0.0
var _generated := false
## Point autour duquel afficher le monde (caméra libre du mode construction) ; INF = le héros.
var stream_focus := Vector3.INF
## Cases modifiées par le joueur (terrassement, décor récolté) : case -> [hauteur, type, décor].
var _edits := {}


func _ready() -> void:
	add_to_group("world")
	build = get_node_or_null("Build") as BuildGrid
	if Engine.is_editor_hint():
		return
	# une construction ou une démolition rend caduques les chemins impossibles et le cache du décor
	if build:
		build.changed.connect(invalidate_paths)
	if get_node_or_null("Donjons") == null:
		var dm := DungeonManager.new()
		dm.name = "Donjons"
		add_child(dm)
	if get_node_or_null("Chantiers") == null:
		var bo := BuildOrders.new()
		bo.name = "Chantiers"
		add_child(bo)
	if get_node_or_null("Expeditions") == null:
		var ex := Expeditions.new()
		ex.name = "Expeditions"
		add_child(ex)
	if get_node_or_null("Menaces") == null:
		var rm := RaidManager.new()
		rm.name = "Menaces"
		add_child(rm)
	apply_quality.call_deferred(int(SaveGame.options.get("graphics", 2)))
	if generate_on_start and pregenerated:
		# l'écran de chargement a déjà calculé le monde : il reste la 3D
		generate_nodes()
		if SaveGame.pending_seed() >= 0:
			SaveGame.apply_pending.call_deferred(self)
	elif generate_on_start:
		var loaded_seed := SaveGame.pending_seed()
		if loaded_seed >= 0:
			# la taille du monde de la sauvegarde (les parties d'avant le monde immense : 640 × 640 m)
			var sz: Array = SaveGame.pending.world.get("size", [640, 640])
			world_size = Vector2i(int(sz[0]), int(sz[1]))
			generate(loaded_seed)
			SaveGame.apply_pending.call_deferred(self)
		else:
			var forced: int = GameState.world_seed
			generate(forced if forced >= 0 else (randi() if random_seed_on_start else world_seed))


func _editor_preview() -> void:
	generate(world_seed)


func _content_root() -> Node3D:
	var n := get_node_or_null("Contenu") as Node3D
	if n == null:
		n = Node3D.new()
		n.name = "Contenu"
		add_child(n)
	return n


func clear() -> void:
	for holder in [$Terrain, $Decor, $Village, _content_root()]:
		for child in holder.get_children():
			child.free()
	_terrain_nodes.clear()
	_decor_nodes.clear()
	_content_nodes.clear()
	_generated = false
	if build:
		build.clear()


## Avancement de la création du monde (0 à 1) et son étape, pour l'écran de chargement (voir LoadingScreen).
var gen_progress := 0.0
var gen_stage := ""
## Les données du monde ont déjà été calculées (par l'écran de chargement, en arrière-plan) :
## à l'entrée dans l'arbre, il ne reste qu'à bâtir la 3D.
var pregenerated := false


func _progress(p: float, stage := "") -> void:
	gen_progress = p
	if stage != "":
		gen_stage = stage


## Crée tout le monde d'un coup (écran titre, tests). Le jeu, lui, passe par l'écran de chargement :
## prepare_generation, puis generate_data en arrière-plan, puis generate_nodes.
func generate(seed_value: int) -> void:
	prepare_generation(seed_value)
	generate_data()
	generate_nodes()


## Prépare la création (fil principal : chargement des régions, nettoyage).
func prepare_generation(seed_value: int) -> void:
	_progress(0.0, "Préparation...")
	world_seed = seed_value
	_ensure_noises()
	height_noise.seed = seed_value
	moisture_noise.seed = seed_value + 1
	_warp_noise.seed = seed_value + 2
	_ridge_noise.seed = seed_value + 3
	_rng.seed = seed_value
	clear()
	_load_region_types()

	var n := world_size.x * world_size.y
	for arr in [_types, _decor, _zone, _zone2, _blend, _revealed]:
		arr.resize(n)
		arr.fill(0)
	_heights.resize(n)
	_chunks = Vector2i(ceili(world_size.x / float(CHUNK)), ceili(world_size.y / float(CHUNK)))
	_chunk_ready.resize(_chunks.x * _chunks.y)
	_chunk_ready.fill(0)
	_taken.clear()
	_edits.clear()
	_island_cache.clear()
	_recruited.clear()
	removed_props.clear()
	opened_chests.clear()
	decor_damage.clear()
	prop_damage.clear()
	_camp_cells.clear()
	current_zone = -1
	map_image = Image.create(world_size.x, world_size.y, false, Image.FORMAT_RGBA8)
	map_image.fill(Color(0, 0, 0, 0))
	map_texture = ImageTexture.create_from_image(map_image)


## Les données du monde : relief, régions, capitales, routes, lieux. Ne touche pas à l'arbre de scène :
## l'écran de chargement l'appelle dans un fil à part et affiche l'avancement.
func generate_data() -> void:
	_progress(0.02, "Formation des régions...")
	_make_zones()
	var center := Vector2(world_size) / 2.0
	_progress(0.05, "Le village s'installe...")
	spawn_cell = _find_spawn(center)
	_make_clearing(spawn_cell)
	_progress(0.08, "Fondation des capitales...")
	_plan_cities()
	_progress(0.3, "Tracé des routes...")
	_plan_roads()
	_progress(0.45, "Obélisques et donjons...")
	_place_sites()
	_progress(0.75, "Châteaux, ruines et épaves...")
	_plan_structures()
	_progress(0.9, "Hameaux et cités englouties...")
	_plan_hamlets()
	_plan_sunken()
	_progress(0.92, "Construction du monde...")


## La 3D du monde (fil principal) : eau, terrain autour du héros, constructions.
func generate_nodes() -> void:
	var seed_value := world_seed
	_build_water()
	# les bornes de la zone du camp (autour du drapeau du royaume)
	if get_node_or_null("CampBorder") == null:
		var cb := CampBorder.new()
		cb.name = "CampBorder"
		add_child(cb)
	_generated = true
	var focus := cell_center(spawn_cell)
	_stream(focus, true)
	_place_player()
	if not Engine.is_editor_hint():
		_build_village()
		_build_structures()
		_build_cities()
		_build_bridges()
		reveal(focus, REVEAL_RADIUS + 10)
	world_generated.emit(seed_value)


const NAME_KINDS := {
	"prairie": ["Prés", "Plaines", "Vallon", "Collines", "Champs", "Coteaux"],
	"foret": ["Forêt", "Bois", "Futaie", "Sylve", "Hallier"],
	"bois_enchante": ["Clairière", "Jardins", "Vallée", "Sylve", "Bosquets"],
	"marais": ["Marais", "Tourbières", "Fondrières", "Marécages"],
	"desert": ["Désert", "Dunes", "Erg", "Plateau", "Oasis"],
	"montagnes": ["Pics", "Monts", "Cols", "Crêtes", "Hauts"],
	"toundra": ["Toundra", "Glaciers", "Steppes", "Plaines gelées"],
	"volcan": ["Terres", "Caldeira", "Coulées", "Brasiers"],
	"jungle": ["Jungle", "Canopée", "Forêt vierge", "Mangroves"],
}
const NAME_START := ["Clair", "Mor", "Bel", "Haut", "Ros", "Fon", "Ver", "Aube", "Gris", "Sombre", "Or", "Lune",
	"Brume", "Roc", "Val", "Ombre", "Givre", "Cendre", "Saule", "Ronce", "Aigle", "Loup", "Fer", "Étoile"]
const NAME_END := ["val", "mont", "bois", "fleur", "combe", "lande", "pierre", "rive", "garde", "fosse", "croix",
	"pré", "lac", "roche", "vent", "court", "brune", "ciel", "sang", "dor"]


## Un nom de zone inventé : « Monts de Grisroche », « Dunes d'Orvent »...
func _compose_name(region_id: String, rng: RandomNumberGenerator) -> String:
	var kinds: Array = NAME_KINDS.get(region_id, ["Terres"])
	var root: String = NAME_START[rng.randi() % NAME_START.size()] + NAME_END[rng.randi() % NAME_END.size()]
	var de := "d'" if "AEÉIOUY".contains(root.substr(0, 1)) else "de "
	return "%s %s%s" % [kinds[rng.randi() % kinds.size()], de, root]


func _load_region_types() -> void:
	region_types.clear()
	var dir := DirAccess.open(regions_dir)
	if dir == null:
		return
	var files := Array(dir.get_files())
	files.sort()
	for f in files:
		var fname: String = f.trim_suffix(".remap")
		if fname.ends_with(".tres"):
			var r := load(regions_dir.path_join(fname)) as RegionData
			if r:
				region_types.append(r)


# ---------------------------------------------------------------- zones

## Découpe le monde en zones (un point par case de `zone_size`, un peu décalé) et choisit leur région.
func _make_zones() -> void:
	zones.clear()
	var zrng := RandomNumberGenerator.new()
	zrng.seed = world_seed + 7
	var grid := Vector2i(ceili(world_size.x / float(zone_size)), ceili(world_size.y / float(zone_size)))
	var center := Vector2(world_size) / 2.0
	var half := minf(world_size.x, world_size.y) * 0.5
	var used_names := {}
	var start_id := -1
	for gy in grid.y:
		for gx in grid.x:
			var site := Vector2((gx + 0.2 + zrng.randf() * 0.6) * zone_size, (gy + 0.2 + zrng.randf() * 0.6) * zone_size)
			var z := {"id": zones.size(), "site": site, "grid": Vector2i(gx, gy), "type": null, "name": "",
				"level": Vector2i(1, 3), "obelisk": Vector2i(-1, -1), "gate": Vector2i(-1, -1),
				"discovered": false, "obelisk_on": false, "dist": site.distance_to(center) / half}
			zones.append(z)
	# la zone du centre accueille le village
	var best := INF
	for z in zones:
		var d: float = (z.site as Vector2).distance_to(center)
		if d < best:
			best = d
			start_id = z.id
	zones[start_id].site = center
	zones[start_id].dist = 0.0
	# région de chaque zone : climat (nord froid, sud chaud) + humidité + éloignement
	var prairie: RegionData = null
	for r in region_types:
		if r.min_distance <= 0.0:
			prairie = r
			break
	for z in zones:
		var site: Vector2 = z.site
		var d: float = z.dist
		if z.id == start_id or region_types.is_empty():
			z.type = prairie if prairie else (region_types[0] if not region_types.is_empty() else null)
		else:
			var temp := clampf((site.y / world_size.y) * 2.2 - 1.1 + zrng.randf_range(-0.35, 0.35), -1.0, 1.0)
			var moist := clampf(moisture_noise.get_noise_2d(site.x * 0.2, site.y * 0.2) * 2.5 + zrng.randf_range(-0.4, 0.4), -1.0, 1.0)
			var choice: RegionData = null
			var score := INF
			for r in region_types:
				if r.min_distance > d:
					continue
				var s := pow(temp - r.temperature, 2.0) + pow(moist - r.moisture, 2.0) + zrng.randf() * 0.25
				if r == prairie and d > 0.7:
					s += 1.0
				# variété : on évite la même région que les voisines déjà choisies, et les régions déjà fréquentes
				for o in zones:
					if o.type == r:
						s += 0.12
						if (o.grid as Vector2i).distance_to(z.grid) < 1.5:
							s += 0.35
				if s < score:
					score = s
					choice = r
			z.type = choice if choice else prairie
		var t: RegionData = z.type
		if t == null:
			continue
		# nom de la zone
		var names := Array(t.names)
		names.shuffle()
		var nm := ""
		for cand in names:
			if not used_names.has(cand):
				nm = cand
				break
		# monde immense : quand les noms de la région sont épuisés, on en compose de nouveaux
		var tries := 0
		while nm == "" or used_names.has(nm):
			nm = _compose_name(t.id, zrng)
			tries += 1
			if tries > 40:
				nm = "%s %d" % [t.display_name, zones.filter(func(o): return o.type == t).size()]
				break
		used_names[nm] = true
		z.name = nm
		# niveau : plus loin du village = plus fort
		var span := t.level_range.y - t.level_range.x
		var k := clampf((d - t.min_distance) / maxf(0.1, 1.2 - t.min_distance), 0.0, 1.0)
		var lo := t.level_range.x + roundi(span * k * 0.6)
		z.level = Vector2i(lo, mini(t.level_range.y, lo + 3))
	current_zone = -1


func _zone_type(id: int) -> RegionData:
	return zones[id].type if id >= 0 and id < zones.size() else null


## Les deux zones les plus proches d'une case (position déformée pour des frontières naturelles).
func _nearest_zones(x: int, y: int) -> Array:
	var p := Vector2(x, y) + Vector2(_warp_noise.get_noise_2d(x, y), _warp_noise.get_noise_2d(x + 913, y - 377)) * 26.0
	var gx := clampi(floori(p.x / zone_size), 0, 1000)
	var gy := clampi(floori(p.y / zone_size), 0, 1000)
	var grid_w := ceili(world_size.x / float(zone_size))
	var grid_h := ceili(world_size.y / float(zone_size))
	var b1 := -1
	var b2 := -1
	var d1 := INF
	var d2 := INF
	for oy in range(-1, 2):
		for ox in range(-1, 2):
			var cx := gx + ox
			var cy := gy + oy
			if cx < 0 or cy < 0 or cx >= grid_w or cy >= grid_h:
				continue
			var id := cy * grid_w + cx
			var d: float = p.distance_squared_to(zones[id].site)
			if d < d1:
				d2 = d1
				b2 = b1
				d1 = d
				b1 = id
			elif d < d2:
				d2 = d
				b2 = id
	if b2 < 0:
		b2 = b1
	# part de la zone voisine : 50 % sur la frontière, 0 % à `region_blend` mètres
	var gap := sqrt(d2) - sqrt(d1)
	var f := clampf(0.5 - gap / (2.0 * region_blend), 0.0, 0.5)
	return [b1, b2, f]


## Zone (Dictionary) sous une position, ou {} hors du monde.
func zone_at(pos: Vector3) -> Dictionary:
	var cell := cell_at(pos)
	if not _inside(cell) or zones.is_empty():
		return {}
	_ensure_chunk_of(cell)
	return zones[_zone[_idx(cell)]]


func region_at(pos: Vector3) -> RegionData:
	var z := zone_at(pos)
	return z.type if not z.is_empty() else null


# ---------------------------------------------------------------- génération par morceaux

func _ensure_chunk_of(cell: Vector2i) -> void:
	if not _inside(cell):
		return
	var ci := (cell.y / CHUNK) * _chunks.x + (cell.x / CHUNK)
	# garde-fou : sur la CI, une partie d'un monde de 1536 m rechargée en 640 m (test_boot) a demandé des morceaux
	# hors de la grille ; on n'a rien à calculer
	if ci >= _chunk_ready.size():
		return
	if _chunk_ready[ci] == 0:
		_gen_chunk_data(Vector2i(cell.x / CHUNK, cell.y / CHUNK))


func _rand(x: int, y: int, salt: int) -> float:
	return float(hash(Vector3i(x, y, world_seed * 31 + salt)) & 0xFFFFFF) / 16777215.0


## Calcule le sol, la région et les décors d'un morceau (une seule fois).
func _gen_chunk_data(ch: Vector2i) -> void:
	var ci := ch.y * _chunks.x + ch.x
	if _chunk_ready[ci] != 0:
		return
	_chunk_ready[ci] = 1
	var center := Vector2(world_size) / 2.0
	for y in range(ch.y * CHUNK, mini((ch.y + 1) * CHUNK, world_size.y)):
		for x in range(ch.x * CHUNK, mini((ch.x + 1) * CHUNK, world_size.x)):
			var i := y * world_size.x + x
			var nz := _nearest_zones(x, y)
			var z1: int = nz[0]
			var z2: int = nz[1]
			var f: float = nz[2]
			_zone[i] = z1
			_zone2[i] = z2
			_blend[i] = int(f * 254.0)
			var r1 := _zone_type(z1)
			var r2 := _zone_type(z2)
			var bias := lerpf(r1.height_bias if r1 else 0.0, r2.height_bias if r2 else 0.0, f)
			var relief := lerpf(r1.relief if r1 else 1.0, r2.relief if r2 else 1.0, f)
			var d := (Vector2(x, y) - center) / center
			var edge := maxf(absf(d.x), absf(d.y))
			var h := height_noise.get_noise_2d(x, y) * relief + bias - pow(edge, 4.0) * island_falloff + land_bias
			# hautes montagnes : des crêtes qui montent très haut dans les régions de montagne
			var peak := lerpf(float(PEAKS.get(r1.id if r1 else "", 0.0)), float(PEAKS.get(r2.id if r2 else "", 0.0)), f)
			if peak > 0.0 and h > sand_level:
				var ridge := 1.0 - absf(_ridge_noise.get_noise_2d(x, y))
				h += peak * ridge * ridge * ridge * clampf((h - sand_level) * 4.0, 0.0, 1.0)
			# îles au trésor, au large
			var isl := _island_height(x, y)
			if isl > h:
				h = isl
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
			_types[i] = t
			_heights[i] = _terrain_height(t, h)
			_decor[i] = _pick_decor(x, y, t, h, m, r1)
			if isl > -INF and _island_center_cell(x, y):
				_decor[i] = D_NONE


## Type et hauteur d'une case calculés directement (comme _gen_chunk_data, sans les îles ni les retouches),
## sans générer son morceau : pour évaluer vite un emplacement lointain.
func _quick_cell(x: int, y: int) -> Vector2:
	var nz := _nearest_zones(x, y)
	var f: float = nz[2]
	var r1 := _zone_type(nz[0])
	var r2 := _zone_type(nz[1])
	var bias := lerpf(r1.height_bias if r1 else 0.0, r2.height_bias if r2 else 0.0, f)
	var relief := lerpf(r1.relief if r1 else 1.0, r2.relief if r2 else 1.0, f)
	var center := Vector2(world_size) / 2.0
	var d := (Vector2(x, y) - center) / center
	var edge := maxf(absf(d.x), absf(d.y))
	var h := height_noise.get_noise_2d(x, y) * relief + bias - pow(edge, 4.0) * island_falloff + land_bias
	var peak := lerpf(float(PEAKS.get(r1.id if r1 else "", 0.0)), float(PEAKS.get(r2.id if r2 else "", 0.0)), f)
	if peak > 0.0 and h > sand_level:
		var ridge := 1.0 - absf(_ridge_noise.get_noise_2d(x, y))
		h += peak * ridge * ridge * ridge * clampf((h - sand_level) * 4.0, 0.0, 1.0)
	var t := GRASS
	if h < deep_water_level:
		t = DEEP
	elif h < water_level:
		t = WATER
	elif h < sand_level:
		t = SAND
	elif h > stone_level:
		t = STONE
	return Vector2(t, _terrain_height(t, h))


# ---------------------------------------------------------------- îles au trésor

## Une île possible par carré de ISLAND_GRID cases, au milieu des eaux profondes.
const ISLAND_GRID := 48
const ISLAND_CHANCE := 0.4
var _island_cache := {}


## Hauteur « brute » d'une case (sans les îles), comme à la génération.
func _base_height(x: int, y: int) -> float:
	var nz := _nearest_zones(x, y)
	var r1 := _zone_type(nz[0])
	var r2 := _zone_type(nz[1])
	var f: float = nz[2]
	var bias := lerpf(r1.height_bias if r1 else 0.0, r2.height_bias if r2 else 0.0, f)
	var relief := lerpf(r1.relief if r1 else 1.0, r2.relief if r2 else 1.0, f)
	var center := Vector2(world_size) / 2.0
	var d := (Vector2(x, y) - center) / center
	var edge := maxf(absf(d.x), absf(d.y))
	return height_noise.get_noise_2d(x, y) * relief + bias - pow(edge, 4.0) * island_falloff + land_bias


## L'île d'un carré : {"id", "cell", "pos", "r"} ou {} s'il n'y en a pas.
func island_of(g: Vector2i) -> Dictionary:
	if _island_cache.has(g):
		return _island_cache[g]
	var out := {}
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(world_seed, g.x * 131 + g.y, 9191))
	if rng.randf() < ISLAND_CHANCE:
		var c := Vector2i(g.x * ISLAND_GRID + rng.randi_range(10, ISLAND_GRID - 10), g.y * ISLAND_GRID + rng.randi_range(10, ISLAND_GRID - 10))
		var r := rng.randi_range(4, 7)
		# seulement en pleine mer : le centre et le tour doivent être profonds
		if _inside(c) and _base_height(c.x, c.y) < deep_water_level - 0.08 \
				and _base_height(c.x + r + 4, c.y) < deep_water_level and _base_height(c.x - r - 4, c.y) < deep_water_level \
				and _base_height(c.x, c.y + r + 4) < deep_water_level and _base_height(c.x, c.y - r - 4) < deep_water_level:
			out = {"id": "%d_%d" % [g.x, g.y], "cell": c, "r": float(r)}
	_island_cache[g] = out
	return out


## Hauteur apportée par une île proche (-INF s'il n'y en a pas).
func _island_height(x: int, y: int) -> float:
	var g := Vector2i(x / ISLAND_GRID, y / ISLAND_GRID)
	var best := -INF
	for dz in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			var isl := island_of(g + Vector2i(dx, dz))
			if isl.is_empty():
				continue
			var d := Vector2(x, y).distance_to(Vector2(isl.cell))
			if d > isl.r:
				continue
			# sable au bord, herbe au milieu
			best = maxf(best, sand_level - 0.03 + (1.0 - d / isl.r) * 0.2)
	return best


func _island_center_cell(x: int, y: int) -> bool:
	var isl := island_of(Vector2i(x / ISLAND_GRID, y / ISLAND_GRID))
	return not isl.is_empty() and isl.cell == Vector2i(x, y)


## Îles proches d'une position (rayon en carrés d'îles) : [{"id", "pos"}, ...].
func islands_near(pos: Vector3, radius := 2) -> Array:
	var out := []
	var g := Vector2i(floori(pos.x) / ISLAND_GRID, floori(pos.z) / ISLAND_GRID)
	for dz in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var isl := island_of(g + Vector2i(dx, dz))
			if not isl.is_empty():
				out.append({"id": isl.id, "pos": cell_center(isl.cell)})
	return out


func _terrain_height(t: int, h: float) -> float:
	match t:
		DEEP:
			# plus on s'éloigne du rivage, plus c'est profond (jusqu'à 6 m) : on peut y plonger
			return -1.5 - floorf(clampf((deep_water_level - h) * 30.0, 0.0, 9.0)) * 0.5
		WATER:
			return -0.75
		SAND:
			return 0.0
		STONE:
			# la roche monte deux fois plus vite par marches de 0,5 m (on peut gravir les pentes douces)
			var top := step_height * (1.0 + floorf((stone_level - sand_level) / terrace_size))
			return top + step_height * stone_step_multiplier * (1.0 + floorf((h - stone_level) / (terrace_size * 0.5)))
	return step_height * (1.0 + floorf((h - sand_level) / terrace_size))


func _pick_decor(x: int, y: int, t: int, h: float, m: float, r: RegionData) -> int:
	var a := _rand(x, y, 1)
	var b := _rand(x, y, 2)
	var forest := r.forest_density if r else 0.3
	var scattered := r.scattered_tree_chance if r else 0.015
	var bush := r.bush_chance if r else 0.02
	var rock := r.rock_chance if r else 0.06
	var plant := r.small_plant_chance if r else 0.1
	# arbres en quinconce (au moins 2,2 m entre deux troncs : on passe toujours entre eux),
	# et quelques clairières dans les bois
	var tree_ok := x % 2 == 0 and (y + (x / 2) % 2) % 2 == 0 and _rand(x / 8, y / 8, 41) >= CLEARING_CHANCE
	if t == STONE:
		# filons : du fer dans toute la roche, de l'or plus rare sur les hauteurs
		var ore := _rand(x, y, 5)
		if h > stone_level + 0.12 and ore < GOLD_CHANCE:
			return D_GOLD
		if ore < IRON_CHANCE:
			return D_IRON
		if a < rock:
			return D_ROCK
		if tree_ok and b < scattered * 0.6:
			return D_OAK
		return D_NONE
	if t == GRASS:
		# les forêts poussent là où il fait humide (les régions très boisées en ont partout)
		if tree_ok and m > forest_moisture - forest * 0.6 and a < forest:
			return D_OAK
		if tree_ok and a < scattered:
			return D_OAK
		if b < bush:
			return D_BUSH
		if b < bush + rock * 0.25:
			return D_ROCK
		if _rand(x, y, 3) < plant:
			return D_FLOWERS
	elif t == SAND:
		if a < rock * 0.15:
			return D_ROCK
		if r and r.small_plants.size() > 0 and b < plant * 0.2:
			return D_FLOWERS
	return D_NONE


func _find_spawn(center: Vector2) -> Vector2i:
	# case d'herbe la plus proche du centre, entourée de terre ferme
	var c := Vector2i(center)
	for r in range(0, mini(world_size.x, world_size.y) / 2):
		for y in range(c.y - r, c.y + r + 1):
			for x in range(c.x - r, c.x + r + 1):
				if absi(x - c.x) != r and absi(y - c.y) != r:
					continue
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
			_ensure_chunk_of(c)
			var i := _idx(c)
			var t := _types[i]
			if t == WATER or t == DEEP:
				continue
			var d := Vector2(x, y).length()
			if d <= r + 2:
				_decor[i] = D_NONE if d <= r else _decor[i]
				_heights[i] = base
				if d <= plaza_radius + 0.5:
					# départ à mains nues : pas de place dallée, juste de l'herbe
					_types[i] = GRASS if GameState.bare_start else PLAZA
					_decor[i] = D_NONE
				elif d <= r and t == STONE:
					_types[i] = GRASS
			elif d <= r + 2 + blend:
				# pente douce entre la clairière et le reste du terrain
				var k := (d - r - 2) / float(blend)
				_heights[i] = snappedf(lerpf(base, _heights[i], k), step_height)


## Aplanit une petite place (lieux : obélisques, donjons).
func _flatten_spot(cell: Vector2i, radius: int) -> void:
	var base := _h(cell)
	for y in range(-radius, radius + 1):
		for x in range(-radius, radius + 1):
			var c := cell + Vector2i(x, y)
			if not _inside(c):
				continue
			_ensure_chunk_of(c)
			var i := _idx(c)
			_decor[i] = D_NONE
			if absf(_heights[i] - base) < 1.6 and _types[i] != WATER and _types[i] != DEEP:
				_heights[i] = base


## Cherche une case sèche et plate près de `from` (en spirale).
func _find_site(from: Vector2i, zone_id: int, max_r: int) -> Vector2i:
	for r in range(0, max_r, 2):
		for y in range(from.y - r, from.y + r + 1, 2):
			for x in range(from.x - r, from.x + r + 1, 2):
				if absi(x - from.x) != r and absi(y - from.y) != r:
					continue
				var c := Vector2i(x, y)
				if not _inside(c) or c.x < 4 or c.y < 4 or c.x >= world_size.x - 4 or c.y >= world_size.y - 4:
					continue
				var t := _type(c)
				if t != GRASS and t != SAND and t != STONE:
					continue
				if zone_id >= 0 and _zone[_idx(c)] != zone_id:
					continue
				if not city_at(Vector3(c.x, 0, c.y), 8.0).is_empty():
					continue
				if not _is_dry_area(c, 3):
					continue
				var ok := true
				for o in [Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2)]:
					if absf(_h(c + o) - _h(c)) > 1.0:
						ok = false
				if ok:
					return c
	return Vector2i(-1, -1)


## Place un obélisque et une entrée de donjon dans chaque zone.
func _place_sites() -> void:
	for z in zones:
		_progress(lerpf(0.45, 0.75, float(z.id) / zones.size()))
		var site: Vector2 = z.site
		var start: bool = z.dist == 0.0
		var ob: Vector2i
		if start:
			ob = spawn_cell + Vector2i(-8, -8)
		else:
			ob = _find_site(Vector2i(site), z.id, 44)
			if ob.x < 0:
				ob = _find_site(Vector2i(site), -1, 80)
		if ob.x >= 0:
			z.obelisk = ob
			if not start:
				_flatten_spot(ob, 2)
			else:
				_ensure_chunk_of(ob)
				_decor[_idx(ob)] = D_NONE
			if start:
				z.obelisk_on = true
		if not start:
			var dir := Vector2.from_angle(_rand(z.id, 5, 9) * TAU)
			var gate := _find_site(Vector2i(site + dir * 30.0), z.id, 36)
			if gate.x >= 0 and (z.obelisk as Vector2i).distance_to(gate) > 12:
				z.gate = gate
				_flatten_spot(gate, 3)


# ---------------------------------------------------------------- requêtes

func _idx(cell: Vector2i) -> int:
	return cell.y * world_size.x + cell.x


func _inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < world_size.x and cell.y < world_size.y


func _type(cell: Vector2i) -> int:
	if not _inside(cell):
		return DEEP
	_ensure_chunk_of(cell)
	return _types[_idx(cell)]


func _h(cell: Vector2i) -> float:
	if not _inside(cell):
		return SEA_FLOOR
	_ensure_chunk_of(cell)
	return _heights[_idx(cell)]


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
	if feet < UNDERGROUND:
		# dans un donjon : seul le sol du donjon compte (sinon on reste à sa hauteur)
		var d := dungeon_grid.support(cell, feet + max_step) if dungeon_grid else -INF
		return d if d > -INF else feet
	var t := _type(cell)
	var g := _h(cell)
	if (t == WATER or t == DEEP) and g < water_surface:
		g = water_surface
	if build:
		g = maxf(g, build.support(cell, feet + max_step))
	return g


func is_walkable(pos: Vector3) -> bool:
	var cell := cell_at(pos)
	if pos.y < UNDERGROUND:
		return dungeon_grid != null and dungeon_grid.support(cell, pos.y + max_step) > -INF
	var t := _type(cell)
	if t != WATER and t != DEEP:
		return true
	return build != null and build.support(cell, 1000.0) > water_surface


## Empêche d'entrer dans l'eau, de monter une marche trop haute ou de traverser un mur.
## Glisse le long de l'obstacle si possible.
## `swim` : on peut entrer dans l'eau (le héros sait nager).
func constrain_move(from: Vector3, to: Vector3, swim := false) -> Vector3:
	if _can_step(from, to, swim):
		return to
	var only_x := Vector3(to.x, to.y, from.z)
	if _can_step(from, only_x, swim):
		return only_x
	var only_z := Vector3(from.x, to.y, to.z)
	if _can_step(from, only_z, swim):
		return only_z
	return Vector3(from.x, to.y, from.z)


func _can_step(from: Vector3, to: Vector3, swim := false) -> bool:
	var dir := Vector3(to.x - from.x, 0, to.z - from.z)
	var probe := to
	if dir.length_squared() > 0.000001:
		probe += dir.normalized() * 0.22
	# en l'air (saut), on peut monter sur ce qui est sous ses pieds
	var h_from := maxf(ground_height_at(from), from.y - 0.05)
	for p in [probe, to]:
		var cell := cell_at(p)
		if not _inside(cell):
			return false
		if not step_ok(cell, h_from, swim):
			return false
	return true


## Peut-on aller sur la case `cell` en partant d'une hauteur `h_from` ?
func step_ok(cell: Vector2i, h_from: float, swim := false) -> bool:
	if h_from < UNDERGROUND:
		if dungeon_grid == null:
			return false
		var ds := dungeon_grid.support(cell, h_from + max_step)
		return ds > -INF and ds - h_from <= max_step and not dungeon_grid.body_blocked(cell, ds)
	var hs := support_height(Vector3(cell.x + 0.5, 0, cell.y + 0.5), h_from)
	var t := _type(cell)
	if (t == WATER or t == DEEP) and hs <= water_surface + 0.01:
		return swim
	if hs - h_from > max_step:
		return false
	if build and build.body_blocked(cell, hs):
		return false
	return true


## Chemin (liste de points) entre deux positions, en passant par les portes (A*, cases voisines).
## `through_build` : ignore les blocs construits (les pillards passent au travers en les cassant).
func find_path(from: Vector3, to: Vector3, max_nodes := 2500, through_build := false) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var start := cell_at(from)
	var goal := cell_at(to)
	if start == goal:
		out.append(to)
		return out
	# un chemin impossible n'est pas recherché à nouveau avant quelques secondes
	var now := Time.get_ticks_msec()
	var memo_key := Vector4i(start.x, start.y, goal.x, goal.y)
	if _path_fail.has(memo_key) and now - int(_path_fail[memo_key]) < PATH_FAIL_MEMO_MS:
		return out
	if now - _prop_cache_time > PROP_CACHE_MS:
		_prop_cache.clear()
		_prop_cache_time = now
	# pas de recherche démesurée pour un but proche : le détour autorisé dépend de la distance
	var dist := Vector2(start - goal).length()
	max_nodes = mini(max_nodes, 400 + int(dist * dist * 4.0))
	# A* avec un tas binaire (file de priorité) : [f, ordre d'arrivée, case]
	var heap: Array = []
	var seq := 0
	var came := {start: start}
	var g := {start: 0.0}
	var hgt := {start: ground_height_at(from)}
	var closed := {}
	_heap_push(heap, [Vector2(start - goal).length(), 0, start])
	var visited := 0
	while not heap.is_empty() and visited < max_nodes:
		var cur: Vector2i = _heap_pop(heap)[2]
		if closed.has(cur):
			continue
		closed[cur] = true
		visited += 1
		if cur == goal:
			var path := [cur]
			while path[0] != start:
				path.push_front(came[path[0]])
			for c in path.slice(1):
				out.append(Vector3(c.x + 0.5, hgt[c], c.y + 0.5))
			return out
		for d in DIRS4:
			var n: Vector2i = cur + d
			if closed.has(n) or not _inside(n):
				continue
			if through_build:
				var tn := _type(n)
				var th := _h(n)
				if tn == WATER or tn == DEEP or th - hgt[cur] > max_step:
					continue
			elif not step_ok(n, hgt[cur]):
				continue
			if Vector2(n - goal).length() > 1.5 and _prop_blocked(n, hgt[cur], _prop_cache):
				continue
			var ng: float = g[cur] + 1.0
			if not g.has(n) or ng < g[n]:
				g[n] = ng
				came[n] = cur
				hgt[n] = _h(n) if through_build else support_height(Vector3(n.x + 0.5, 0, n.y + 0.5), hgt[cur])
				seq += 1
				_heap_push(heap, [ng + Vector2(n - goal).length(), seq, n])
	_path_fail[memo_key] = now
	if _path_fail.size() > 512:
		_path_fail.clear()
	return out


const DIRS4: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
## Un chemin impossible n'est pas recherché à nouveau avant ce délai (ms).
const PATH_FAIL_MEMO_MS := 4000
## Le cache « case bloquée par le décor » est vidé régulièrement (le décor et les constructions changent).
const PROP_CACHE_MS := 3000
var _path_fail := {}
var _prop_cache := {}
var _prop_cache_time := 0
var _prop_query: PhysicsShapeQueryParameters3D


func invalidate_paths() -> void:
	_path_fail.clear()
	_prop_cache.clear()


static func _heap_less(a: Array, b: Array) -> bool:
	return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1])


static func _heap_push(h: Array, item: Array) -> void:
	h.append(item)
	var i := h.size() - 1
	while i > 0:
		var parent := (i - 1) >> 1
		if _heap_less(h[i], h[parent]):
			var t = h[i]
			h[i] = h[parent]
			h[parent] = t
			i = parent
		else:
			break


static func _heap_pop(h: Array) -> Array:
	var top: Array = h[0]
	var last: Array = h.pop_back()
	if h.is_empty():
		return top
	h[0] = last
	var i := 0
	var n := h.size()
	while true:
		var l := 2 * i + 1
		var r := l + 1
		var m := i
		if l < n and _heap_less(h[l], h[m]):
			m = l
		if r < n and _heap_less(h[r], h[m]):
			m = r
		if m == i:
			break
		var t = h[i]
		h[i] = h[m]
		h[m] = t
		i = m
	return top


## Vrai si un objet du décor (cabane, tonneau, feu...) occupe la case. Résultats mis en cache dans `cache`.
func _prop_blocked(cell: Vector2i, h: float, cache: Dictionary) -> bool:
	var key := Vector3i(cell.x, cell.y, roundi(h * 2.0))
	if cache.has(key):
		return cache[key]
	# une seule requête réutilisée (en créer une par case coûte cher)
	if _prop_query == null:
		var shape := SphereShape3D.new()
		shape.radius = 0.3
		_prop_query = PhysicsShapeQueryParameters3D.new()
		_prop_query.shape = shape
		_prop_query.collide_with_areas = false
	var q := _prop_query
	q.transform = Transform3D(Basis(), Vector3(cell.x + 0.5, h + 0.6, cell.y + 0.5))
	var blocked := false
	for hit in get_world_3d().direct_space_state.intersect_shape(q, 4):
		if hit.collider is StaticBody3D:
			blocked = true
			break
	cache[key] = blocked
	return blocked


# ---------------------------------------------------------------- terrassement

func terrain_height(cell: Vector2i) -> float:
	return _h(cell)


func terrain_type(cell: Vector2i) -> int:
	return _type(cell)


func decor_at(cell: Vector2i) -> int:
	if not _inside(cell):
		return D_NONE
	_ensure_chunk_of(cell)
	return _decor[_idx(cell)]


## Enlève le décor d'une case (arbre, rocher...). Renvoie son type (D_NONE s'il n'y avait rien).
func remove_decor(cell: Vector2i, refresh := true) -> int:
	if not _inside(cell):
		return D_NONE
	var i := _idx(cell)
	var k := _decor[i]
	_decor[i] = D_NONE
	_edits[cell] = [_heights[i], _types[i], D_NONE]
	if refresh and k != D_NONE and _decor_nodes.has(_chunk_of(cell)):
		_build_decor_chunk(_chunk_of(cell))
	return k


## Change la hauteur d'une case. Le sol remué devient de la terre ; l'eau comblée devient de la terre.
func set_terrain_height(cell: Vector2i, h: float) -> void:
	if not _inside(cell):
		return
	var i := _idx(cell)
	var t := _types[i]
	if (t == WATER or t == DEEP) and h > water_surface:
		_types[i] = DIRT
	elif t == GRASS or t == PLAZA or t == FARM:
		_types[i] = DIRT
	_heights[i] = h
	if _decor[i] != D_NONE:
		_decor[i] = D_NONE
	_edits[cell] = [h, _types[i], D_NONE]


## Change le type de sol d'une case (ex. terre labourée). Penser à appeler refresh_cells ensuite.
func set_terrain_type(cell: Vector2i, t: int) -> void:
	if not _inside(cell):
		return
	var i := _idx(cell)
	_types[i] = t
	_edits[cell] = [_heights[i], t, _decor[i]]


## Vrai s'il y a de l'eau à moins de `r` cases (champ arrosé).
func near_water(cell: Vector2i, r := 4) -> bool:
	for dz in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var t := _type(cell + Vector2i(dx, dz))
			if t == WATER or t == DEEP:
				return true
	return false


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
		if not _terrain_nodes.has(ch):
			continue
		_build_terrain_chunk(ch)
		if decor:
			_build_decor_chunk(ch)
	refresh_map(cells)




# ---------------------------------------------------------------- affichage par morceaux

func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not _generated or player == null:
		return
	var cam := get_viewport().get_camera_3d()
	if cam:
		RenderingServer.global_shader_parameter_set("see_from", cam.global_position)
		RenderingServer.global_shader_parameter_set("see_to", player.global_position + Vector3(0, 0.9, 0))
		RenderingServer.global_shader_parameter_set("see_radius", 1.9)
	if _water_mask_dirty and _water_mask_tex:
		_water_mask_dirty = false
		_water_mask_tex.update(_water_mask)
	_stream_timer -= delta
	if _stream_timer <= 0.0:
		_stream_timer = 0.05
		_stream(stream_focus if stream_focus != Vector3.INF else player.global_position, false)
	if player.global_position.y < UNDERGROUND:
		return
	# carte : on dévoile autour du héros
	if _last_reveal == Vector3.INF or player.global_position.distance_to(_last_reveal) > 2.5:
		reveal(player.global_position, REVEAL_RADIUS)
	_map_timer -= delta
	if _map_dirty and _map_timer <= 0.0:
		_map_timer = 0.4
		_map_dirty = false
		map_texture.update(map_image)
	# zone actuelle, obélisques
	var z := zone_at(player.global_position)
	if not z.is_empty() and z.id != current_zone:
		current_zone = z.id
		var first: bool = not z.discovered
		z.discovered = true
		zone_entered.emit(z)
		if first and player.has_method("gain_xp") and z.dist > 0.0:
			player.gain_xp(15 + 5 * (z.level as Vector2i).x)
	if not z.is_empty() and not z.obelisk_on and (z.obelisk as Vector2i).x >= 0:
		var ob := cell_center(z.obelisk)
		if Vector2(ob.x - player.global_position.x, ob.z - player.global_position.z).length() < 2.6:
			z.obelisk_on = true
			obelisk_activated.emit(z)
			var holder: Node = _content_nodes.get(_chunk_of(z.obelisk))
			if holder:
				var n := holder.get_node_or_null("Obelisque")
				if n:
					VoxelBurst.spawn(n, ob + Vector3(0, 2.5, 0), Color("8af0ff"), 40, 6.0, 0.1, 0.8, "sphere", 8.0, false)


func _chunk_of(cell: Vector2i) -> Vector2i:
	return Vector2i(cell.x / CHUNK, cell.y / CHUNK)


## Qualité graphique (options) : 0 basse, 1 moyenne, 2 haute.
const QUALITY := [
	{"view": 3.0, "small": 25.0, "shadow": false, "shadow_dist": 0.0},
	{"view": 3.75, "small": 40.0, "shadow": true, "shadow_dist": 30.0},
	{"view": 4.5, "small": 60.0, "shadow": true, "shadow_dist": 45.0},
]


## Vue rapprochée (3e ou 1re personne) : brume de profondeur et caméra limitée à la zone chargée.
var close_view := false
var _quality := 2


func set_close_view(on: bool) -> void:
	if on == close_view:
		return
	close_view = on
	# la qualité choisie dans les options (pas une valeur par défaut)
	apply_quality(int(SaveGame.options.get("graphics", _quality)))


## Distance jusqu'à laquelle la caméra dessine en vue rapprochée.
func close_view_far() -> float:
	return view_distance * CHUNK + 8.0


func apply_quality(q: int) -> void:
	_quality = q
	var cfg: Dictionary = QUALITY[clampi(q, 0, QUALITY.size() - 1)]
	view_distance = float(cfg.view)
	small_decor_range = float(cfg.small)
	# vue rapprochée : les petits décors et les ombres ne servent que tout près (mesuré : les ombres
	# coûtent plus de 40 % des appels de dessin en 3e personne)
	if close_view:
		small_decor_range = minf(small_decor_range, 40.0)
	for n in get_tree().get_nodes_in_group("small_decor"):
		(n as GeometryInstance3D).visibility_range_end = small_decor_range
	var sun := get_parent().get_node_or_null("Soleil") as DirectionalLight3D if get_parent() else null
	var dm := get_node_or_null("Donjons") as DungeonManager
	if sun:
		# dans un donjon, l'ombre est coupée et sera rétablie à la sortie
		if dm == null or not dm.active:
			sun.shadow_enabled = bool(cfg.shadow)
		sun.directional_shadow_max_distance = maxf(10.0, float(cfg.shadow_dist) if not close_view else minf(28.0, float(cfg.shadow_dist)))
	_apply_post(q)
	if close_view:
		var pl := get_tree().get_first_node_in_group("player")
		if pl and pl.get("camera"):
			pl.camera.far = close_view_far()


## Rendu de l'image : tons « filmiques », halo des lumières (torches, lave, feu), brume de distance
## (la couleur suit le ciel, voir DayCycle) et couleurs un peu plus riches. Allégé en qualité basse.
func _apply_post(q: int) -> void:
	var we := get_parent().get_node_or_null("Ambiance") as WorldEnvironment if get_parent() else null
	if we == null or we.environment == null:
		return
	var env := we.environment
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.98
	env.tonemap_white = 4.0
	env.glow_enabled = q >= 1
	env.glow_intensity = 0.45
	env.glow_strength = 0.9
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.3
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.fog_enabled = q >= 1 or close_view
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_density = 0.003 if q >= 2 else 0.0042
	if close_view:
		# 3e et 1re personne : on regarde à l'horizon ; le monde s'efface dans la brume avant la fin
		# de la zone chargée (au lieu de s'arrêter net), et rien n'est dessiné au-delà
		var reach := view_distance * CHUNK
		env.fog_mode = Environment.FOG_MODE_DEPTH
		env.fog_density = 1.0
		env.fog_depth_begin = reach * 0.45
		env.fog_depth_end = reach * 0.95
		env.fog_depth_curve = 1.6
		env.fog_sky_affect = 0.6
	if not close_view:
		env.fog_sky_affect = 0.0
	env.fog_aerial_perspective = 0.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.98
	env.adjustment_contrast = 1.08
	env.adjustment_brightness = 1.0


## Crée les morceaux proches de `focus` et libère les morceaux lointains.
## `all_now` : tout construire tout de suite (au chargement), sinon un morceau par appel.
func _stream(focus: Vector3, all_now: bool) -> void:
	var pc := Vector2(focus.x / CHUNK, focus.z / CHUNK)
	var r := view_distance
	var wanted := []
	for cy in range(floori(pc.y - r), ceili(pc.y + r) + 1):
		for cx in range(floori(pc.x - r), ceili(pc.x + r) + 1):
			if cx < 0 or cy < 0 or cx >= _chunks.x or cy >= _chunks.y:
				continue
			var ch := Vector2i(cx, cy)
			var d := (Vector2(cx + 0.5, cy + 0.5) - pc).length()
			if d <= r and not _terrain_nodes.has(ch):
				wanted.append([d, ch])
	wanted.sort_custom(func(a, b): return a[0] < b[0])
	var budget := wanted.size() if all_now else 1 + wanted.size() / 10
	for i in mini(budget, wanted.size()):
		_load_chunk(wanted[i][1])
	# on oublie les morceaux trop loin
	for ch in _terrain_nodes.keys():
		var d := (Vector2(ch.x + 0.5, ch.y + 0.5) - pc).length()
		if d > r + 1.5:
			_unload_chunk(ch)


func _load_chunk(ch: Vector2i) -> void:
	_build_terrain_chunk(ch)
	_build_decor_chunk(ch)
	if not Engine.is_editor_hint():
		_build_content(ch)


func _unload_chunk(ch: Vector2i) -> void:
	for dict in [_terrain_nodes, _decor_nodes]:
		if dict.has(ch):
			if is_instance_valid(dict[ch]):
				dict[ch].queue_free()
			dict.erase(ch)
	if _content_nodes.has(ch):
		var holder: Node = _content_nodes[ch]
		if is_instance_valid(holder):
			holder.set_meta("unloading", true)
			holder.queue_free()
		_content_nodes.erase(ch)


## Vrai si ce morceau est affiché (et a donc ses obstacles).
func is_chunk_loaded(cell: Vector2i) -> bool:
	return _terrain_nodes.has(_chunk_of(cell))


# ---------------------------------------------------------------- couleurs

func _zone_color(cell: Vector2i, key: StringName, fallback: Color) -> Color:
	var i := _idx(cell)
	var r1 := _zone_type(_zone[i])
	var c1: Color = r1.get(key) if r1 else fallback
	var f := _blend[i] / 254.0
	if f <= 0.0:
		return c1
	var r2 := _zone_type(_zone2[i])
	var c2: Color = r2.get(key) if r2 else fallback
	return c1.lerp(c2, f)


func _top_color(cell: Vector2i) -> Color:
	var t := _type(cell)
	var v := (absi(hash(cell * 7 + Vector2i(world_seed % 991, 3))) % 1000) / 1000.0
	var c: Color
	match t:
		DEEP, WATER:
			c = _zone_color(cell, &"water_floor_color", water_floor_color).darkened(0.0 if t == WATER else clampf(0.25 + (-1.5 - _h(cell)) * 0.08, 0.25, 0.6))
		SAND:
			c = _zone_color(cell, &"sand_color", sand_color)
		STONE:
			c = _zone_color(cell, &"stone_color", stone_color)
		PLAZA:
			c = plaza_color if (cell.x + cell.y) % 2 == 0 else plaza_color.darkened(0.08)
		DIRT:
			c = _zone_color(cell, &"dirt_color", dirt_color).lightened(0.12)
		FARM:
			# sillons : une bande sur deux plus sombre ; plus foncée si le champ est arrosé
			c = _zone_color(cell, &"dirt_color", dirt_color).darkened(0.18 if near_water(cell) else 0.02)
			return c.darkened(0.1) if (cell.x % 2 == 0) else c.lightened(0.04)
		_:
			c = _zone_color(cell, &"grass_color", grass_color).lerp(_zone_color(cell, &"grass_dark_color", grass_dark_color), v)
	return c.darkened(v * 0.07) if t != GRASS else c


func _side_color(cell: Vector2i) -> Color:
	match _type(cell):
		SAND, DEEP, WATER:
			return _zone_color(cell, &"sand_color", sand_color).darkened(0.1)
		STONE, PLAZA:
			return _zone_color(cell, &"stone_color", stone_color).darkened(0.08)
		DIRT, FARM:
			return _zone_color(cell, &"dirt_color", dirt_color).darkened(0.05)
	return _zone_color(cell, &"dirt_color", dirt_color)


# ---------------------------------------------------------------- sol 3D

func _ensure_materials() -> void:
	if _terrain_mat:
		return
	_terrain_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = TERRAIN_SHADER
	_terrain_mat.shader = sh
	_terrain_mat.set_shader_parameter("grain", GRAIN)
	_terrain_mat.set_shader_parameter("water_y", water_surface)
	_bind_water_mask(_terrain_mat)
	_liquid_mat = StandardMaterial3D.new()
	_liquid_mat.vertex_color_use_as_albedo = true
	_liquid_mat.vertex_color_is_srgb = true
	_liquid_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_liquid_mat.albedo_texture = GRAIN
	_liquid_mat.roughness = 0.2
	_liquid_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	_lava_mat = StandardMaterial3D.new()
	_lava_mat.vertex_color_use_as_albedo = true
	_lava_mat.vertex_color_is_srgb = true
	_lava_mat.albedo_texture = GRAIN
	_lava_mat.emission_enabled = true
	_lava_mat.emission = Color(1.0, 0.4, 0.1)
	_lava_mat.emission_energy_multiplier = 0.55
	_lava_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS


func _build_terrain_chunk(ch: Vector2i) -> void:
	_ensure_materials()
	if _terrain_nodes.has(ch) and is_instance_valid(_terrain_nodes[ch]):
		_terrain_nodes[ch].queue_free()
	_gen_chunk_data(ch)
	_update_water_mask(ch)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var liquid := SurfaceTool.new()
	liquid.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lava := SurfaceTool.new()
	lava.begin(Mesh.PRIMITIVE_TRIANGLES)
	var has_liquid := false
	var has_lava := false
	for y in range(ch.y * CHUNK, mini((ch.y + 1) * CHUNK, world_size.y)):
		for x in range(ch.x * CHUNK, mini((ch.x + 1) * CHUNK, world_size.x)):
			var cell := Vector2i(x, y)
			_add_column(st, cell)
			var t := _types[_idx(cell)]
			if t == WATER or t == DEEP:
				var r := _zone_type(_zone[_idx(cell)])
				if r and r.liquid_color.a > 0.0:
					var yy := water_surface + 0.03
					var c := r.liquid_color
					var target := lava if r.liquid_glow else liquid
					if not r.liquid_glow:
						c.a = 0.82
					else:
						c = c.darkened(0.3)
					_quad(target, Vector3(x, yy, y + 1), Vector3(x + 1, yy, y + 1), Vector3(x + 1, yy, y), Vector3(x, yy, y),
						Vector3.UP, c.darkened(_rand(x, y, 11) * 0.15), Vector2(x, y), true)
					if r.liquid_glow:
						has_lava = true
					else:
						has_liquid = true
	st.generate_tangents()
	var mi := MeshInstance3D.new()
	mi.name = "Sol_%d_%d" % [ch.x, ch.y]
	mi.mesh = st.commit()
	mi.material_override = _terrain_mat
	if has_liquid:
		var lm := MeshInstance3D.new()
		lm.mesh = liquid.commit()
		lm.material_override = _liquid_mat
		lm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.add_child(lm)
	if has_lava:
		var lv := MeshInstance3D.new()
		lv.mesh = lava.commit()
		lv.material_override = _lava_mat
		lv.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.add_child(lv)
	$Terrain.add_child(mi)
	_terrain_nodes[ch] = mi


func _add_column(st: SurfaceTool, cell: Vector2i) -> void:
	var h := _h(cell)
	var x0 := float(cell.x)
	var z0 := float(cell.y)
	var top := _top_color(cell)
	# l'alpha dit au shader si la neige peut tenir ici (pas dans les contrées chaudes)
	var zr := _zone_type(_zone[_idx(cell)])
	top.a = 0.0 if zr and zr.precipitation in ["sable", "cendres"] else 1.0
	# ombrage des coins : le sol s'assombrit au pied des talus et des murs (UV2.x, 1 = à découvert)
	var ao := []
	for corner in [Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, 0), Vector2i(0, 0)]:
		var higher := 0.0
		for o in [Vector2i(corner.x - 1, corner.y - 1), Vector2i(corner.x, corner.y - 1), Vector2i(corner.x - 1, corner.y), Vector2i(corner.x, corner.y)]:
			if o == Vector2i.ZERO:
				continue
			var dh := _h(cell + o) - h
			if dh > 0.2:
				higher += clampf(dh, 0.0, 1.5) / 1.5
		ao.append(Vector2(1.0 - 0.22 * higher, -1.0))
	_quad(st, Vector3(x0, h, z0 + 1), Vector3(x0 + 1, h, z0 + 1), Vector3(x0 + 1, h, z0), Vector3(x0, h, z0),
		Vector3.UP, top, Vector2(x0, z0), true, ao)
	var side := _side_color(cell)
	var t := _type(cell)
	var lip := top.darkened(0.12) if t == GRASS else side
	for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var nh := _h(cell + dir)
		if nh >= h:
			continue
		# bande d'herbe en haut du talus, terre en dessous
		var lip_bottom := maxf(nh, h - 0.12) if t == GRASS else nh
		_side(st, cell, dir, lip_bottom, h, lip, nh, h)
		if lip_bottom > nh:
			_side(st, cell, dir, nh, lip_bottom, side, nh, h)


## Face d'un talus entre y0 et y1 ; [bottom, top] : le talus entier (le shader l'assombrit vers le pied).
func _side(st: SurfaceTool, cell: Vector2i, dir: Vector2i, y0: float, y1: float, color: Color, bottom := 0.0, top := 0.0) -> void:
	var x0 := float(cell.x)
	var z0 := float(cell.y)
	var n := Vector3(dir.x, 0, dir.y)
	var drop := maxf(top - bottom, 0.01)
	var g0 := Vector2(clampf((y0 - bottom) / drop, 0.0, 1.0), drop)
	var g1 := Vector2(clampf((y1 - bottom) / drop, 0.0, 1.0), drop)
	var g := [g0, g0, g1, g1]
	# couleur un peu plus sombre sur les côtés pour marquer les blocs
	var c := color.darkened(0.05 + 0.04 * absf(dir.x))
	match dir:
		Vector2i(1, 0):
			_quad(st, Vector3(x0 + 1, y0, z0 + 1), Vector3(x0 + 1, y0, z0), Vector3(x0 + 1, y1, z0), Vector3(x0 + 1, y1, z0 + 1), n, c, Vector2(z0, y0), false, g)
		Vector2i(-1, 0):
			_quad(st, Vector3(x0, y0, z0), Vector3(x0, y0, z0 + 1), Vector3(x0, y1, z0 + 1), Vector3(x0, y1, z0), n, c, Vector2(z0, y0), false, g)
		Vector2i(0, 1):
			_quad(st, Vector3(x0, y0, z0 + 1), Vector3(x0 + 1, y0, z0 + 1), Vector3(x0 + 1, y1, z0 + 1), Vector3(x0, y1, z0 + 1), n, c, Vector2(x0, y0), false, g)
		_:
			_quad(st, Vector3(x0 + 1, y0, z0), Vector3(x0, y0, z0), Vector3(x0, y1, z0), Vector3(x0 + 1, y1, z0), n, c, Vector2(x0, y0), false, g)


## Quadrilatère a-b-c-d (sens anti-horaire vu de face).
func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3, color: Color, uv0: Vector2, is_top: bool, uv2s := []) -> void:
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
		st.set_uv2(uv2s[k] if uv2s.size() == 4 else Vector2(1.0, -1.0))
		st.add_vertex(verts[k])


## Le masque de l'eau : tout est « eau » tant qu'un morceau n'est pas construit (l'horizon garde sa mer).
func _make_water_mask() -> void:
	_water_mask = Image.create(world_size.x, world_size.y, false, Image.FORMAT_L8)
	_water_mask.fill(Color.WHITE)
	_water_mask_tex = ImageTexture.create_from_image(_water_mask)
	_water_mask_dirty = false
	if _terrain_mat:
		_bind_water_mask(_terrain_mat)


## Recopie dans le masque les cases d'eau d'un morceau (après génération, creusage, comblement...).
func _update_water_mask(ch: Vector2i) -> void:
	if _water_mask == null:
		return
	for y in range(ch.y * CHUNK, mini((ch.y + 1) * CHUNK, world_size.y)):
		for x in range(ch.x * CHUNK, mini((ch.x + 1) * CHUNK, world_size.x)):
			var t := _types[y * world_size.x + x]
			_water_mask.set_pixel(x, y, Color.WHITE if t == WATER or t == DEEP else Color.BLACK)
	_water_mask_dirty = true


## À brancher sur un matériau qui doit suivre le masque de l'eau.
func _bind_water_mask(mat: ShaderMaterial) -> void:
	if _water_mask_tex == null:
		_make_water_mask()
	mat.set_shader_parameter("water_mask", _water_mask_tex)
	mat.set_shader_parameter("world_size", Vector2(world_size))


func _build_water() -> void:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_opaque;
uniform vec4 water_color : source_color;
uniform sampler2D grain : filter_linear_mipmap, repeat_enable;
uniform sampler2D water_mask : filter_nearest;
uniform vec2 world_size = vec2(1536.0);
// hauteur des petites vagues (deux couches de grain qui glissent en sens contraires)
float waves(vec2 p) {
	float a = texture(grain, p * 0.11 + vec2(TIME * 0.018, TIME * 0.011)).r;
	float b = texture(grain, p * 0.07 - vec2(TIME * 0.012, -TIME * 0.016)).r;
	float c = texture(grain, p * 0.31 + vec2(-TIME * 0.035, TIME * 0.02)).r;
	return a * 0.5 + b * 0.35 + c * 0.15;
}
void fragment() {
	vec3 wp = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// pas d'eau au-dessus de la terre (un trou creusé sous le niveau de la mer reste sec)
	vec2 muv = wp.xz / world_size;
	if (muv.x >= 0.0 && muv.y >= 0.0 && muv.x < 1.0 && muv.y < 1.0 && texture(water_mask, muv).r < 0.5) {
		discard;
	}
	vec2 p = wp.xz;
	// normale des vagues (différences finies), passée dans l'espace de la vue
	float e = 0.35;
	float h0 = waves(p);
	float hx = waves(p + vec2(e, 0.0));
	float hz = waves(p + vec2(0.0, e));
	vec3 n_world = normalize(vec3((h0 - hx) * 2.2, 1.0, (h0 - hz) * 2.2));
	NORMAL = normalize((VIEW_MATRIX * vec4(n_world, 0.0)).xyz);
	// de haut, on voit au travers ; en rasant, l'eau reflète le ciel (Fresnel)
	float fres = pow(1.0 - clamp(dot(normalize(VIEW), NORMAL), 0.0, 1.0), 4.0);
	vec3 deep = water_color.rgb * vec3(0.55, 0.65, 0.75);
	vec3 sky = vec3(0.62, 0.78, 0.95);
	vec3 col = mix(water_color.rgb, deep, smoothstep(0.35, 0.75, h0));
	col = mix(col, sky, fres * 0.55);
	// écume légère sur les crêtes, et reflets du soleil qui scintillent
	col += vec3(smoothstep(0.78, 0.86, h0) * 0.15);
	float glint = step(0.985, texture(grain, p * 1.25 + vec2(TIME * 0.05, TIME * 0.03)).r * texture(grain, p * 0.6 - vec2(TIME * 0.04, -TIME * 0.02)).r + 0.03 * sin(TIME * 2.0 + p.x));
	col += vec3(glint * 0.55);
	ALBEDO = col;
	ALPHA = clamp(water_color.a + fres * 0.25, 0.0, 0.97);
	ROUGHNESS = 0.06;
	SPECULAR = 0.9;
	METALLIC = 0.0;
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
	_make_water_mask()
	_bind_water_mask(mat)
	water.material_override = mat
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	water.position = Vector3(world_size.x / 2.0, water_surface, world_size.y / 2.0)
	$Terrain.add_child(water)
	# fond de l'océan autour de l'île
	# (lui aussi suit le masque de l'eau : pas de fond marin au fond d'un trou creusé dans la terre)
	var floor_mat := ShaderMaterial.new()
	floor_mat.shader = Shader.new()
	floor_mat.shader.code = SEA_FLOOR_SHADER
	floor_mat.set_shader_parameter("albedo", water_floor_color.darkened(0.35))
	floor_mat.set_shader_parameter("grain", GRAIN)
	floor_mat.set_shader_parameter("grain_scale", GRAIN_SCALE)
	_bind_water_mask(floor_mat)
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(world_size) * 3.0
	var sea_floor := MeshInstance3D.new()
	sea_floor.name = "FondMarin"
	sea_floor.mesh = floor_mesh
	sea_floor.material_override = floor_mat
	sea_floor.position = Vector3(world_size.x / 2.0, SEA_FLOOR, world_size.y / 2.0)
	$Terrain.add_child(sea_floor)




# ---------------------------------------------------------------- décors 3D

func _models_for(kind: int, cell: Vector2i) -> Array[PackedScene]:
	var r := _zone_type(_zone[_idx(cell)])
	if r:
		match kind:
			D_OAK, D_PINE:
				if not r.trees.is_empty():
					return r.trees
			D_BUSH:
				if not r.bushes.is_empty():
					return r.bushes
			D_ROCK:
				if not r.rocks.is_empty():
					return r.rocks
			D_FLOWERS, D_GRASS:
				return r.small_plants
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
		D_IRON:
			return _vein_models("iron")
		D_GOLD:
			return _vein_models("gold")
	return []


var _veins := {}


## Modèles des filons (chargés une seule fois).
func _vein_models(kind: String) -> Array[PackedScene]:
	if not _veins.has(kind):
		var list: Array[PackedScene] = []
		for n in (["iron_vein_1", "iron_vein_2"] if kind == "iron" else ["gold_vein_1"]):
			var sc := load("res://scenes/decor/%s.tscn" % n) as PackedScene
			if sc:
				list.append(sc)
		_veins[kind] = list
	return _veins[kind]


func _build_decor_chunk(ch: Vector2i) -> void:
	if _decor_nodes.has(ch) and is_instance_valid(_decor_nodes[ch]):
		_decor_nodes[ch].queue_free()
	_gen_chunk_data(ch)
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
	var small := {}   # scènes de petite végétation
	for y in range(ch.y * CHUNK, mini((ch.y + 1) * CHUNK, world_size.y)):
		for x in range(ch.x * CHUNK, mini((ch.x + 1) * CHUNK, world_size.x)):
			var cell := Vector2i(x, y)
			var kind := _decor[_idx(cell)]
			if kind == D_NONE:
				continue
			var models := _models_for(kind, cell)
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
			if kind == D_FLOWERS or kind == D_GRASS:
				small[scene] = true
			var shape: Shape3D = null
			var shape_y := 0.0
			match kind:
				D_OAK, D_PINE:
					shape = _trunk_shape
					shape_y = 1.5
				D_BUSH:
					shape = _bush_shape
					shape_y = 0.5
				D_ROCK, D_IRON, D_GOLD:
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
		if small.has(scene):
			mmi.add_to_group("small_decor")
			mmi.visibility_range_end = small_decor_range
		holder.add_child(mmi)
	$Decor.add_child(holder)
	_decor_nodes[ch] = holder


# ---------------------------------------------------------------- contenu des morceaux

## Camps de monstres, objets au sol, obélisques et donjons d'un morceau (recréés à chaque affichage).
func _build_content(ch: Vector2i) -> void:
	var holder := Node3D.new()
	holder.name = "Contenu_%d_%d" % [ch.x, ch.y]
	_content_root().add_child(holder)
	_content_nodes[ch] = holder
	var origin := cell_center(spawn_cell)
	# lieux
	for z in zones:
		if _chunk_of(z.obelisk) == ch and (z.obelisk as Vector2i).x >= 0:
			_add_obelisk(holder, z)
		if _chunk_of(z.gate) == ch and (z.gate as Vector2i).x >= 0:
			_add_gate(holder, z)
	# châteaux et épaves : coffres, garnison ou morts-vivants
	for st in structure_sites:
		if st.kind == "hamlet":
			if _chunk_of(st.cell) == ch:
				_add_hamlet_content(holder, st)
			continue
		if st.kind != "castle" and st.kind != "wreck" and st.kind != "sunken":
			continue
		var center: Vector2i = st.cell + {"castle": Vector2i(10, 10), "wreck": Vector2i(1, 6), "sunken": Vector2i(7, 7)}[st.kind]
		if _chunk_of(center) == ch:
			_add_structure_content(holder, st, center)
	# camp de monstres (un au plus par morceau)
	var crng := RandomNumberGenerator.new()
	crng.seed = hash(Vector3i(ch.x, ch.y, world_seed + 555))
	var cell := Vector2i(ch.x * CHUNK + crng.randi_range(2, CHUNK - 3), ch.y * CHUNK + crng.randi_range(2, CHUNK - 3))
	if _inside(cell) and city_at(Vector3(cell.x, 0, cell.y), 30.0).is_empty():
		var z: Dictionary = zones[_zone[_idx(cell)]]
		var r: RegionData = z.type
		var chance := (r.camp_density if r else 0.5) * CHUNK * CHUNK / 1000.0
		var t := _type(cell)
		var pos := cell_center(cell)
		var far := Vector2(pos.x - origin.x, pos.z - origin.z).length() >= camp_min_distance
		var near_site := (z.obelisk as Vector2i).distance_to(cell) < 8 or (z.gate as Vector2i).distance_to(cell) < 6
		if crng.randf() < chance and far and not near_site and (t == GRASS or t == STONE or t == SAND) \
				and _decor[_idx(cell)] == D_NONE and _is_dry_area(cell, 2):
			_add_camp(holder, cell, z, crng)
	# campement de voyageurs (rare, jamais près d'un camp de monstres ni du village)
	var trng := RandomNumberGenerator.new()
	trng.seed = hash(Vector3i(ch.x, ch.y, world_seed + 909))
	var tcell := Vector2i(ch.x * CHUNK + trng.randi_range(3, CHUNK - 4), ch.y * CHUNK + trng.randi_range(3, CHUNK - 4))
	if _inside(tcell) and city_at(Vector3(tcell.x, 0, tcell.y), 20.0).is_empty():
		var tz: Dictionary = zones[_zone[_idx(tcell)]]
		var tr: RegionData = tz.type
		var tchance := (tr.traveler_density if tr else 0.15) * CHUNK * CHUNK / 1000.0
		var tpos := cell_center(tcell)
		var tfar := Vector2(tpos.x - origin.x, tpos.z - origin.z).length() >= 40.0
		var tt := _type(tcell)
		var no_camp := holder.get_node_or_null("Camp") == null or (holder.get_node("Camp") as Node3D).global_position.distance_to(tpos) > 14.0
		if trng.randf() < tchance and tfar and no_camp and (tt == GRASS or tt == SAND or tt == STONE) \
				and _decor[_idx(tcell)] == D_NONE and _is_dry_area(tcell, 2):
			_add_travelers(holder, tcell, tz, trng)
	# objets à ramasser
	for y in range(ch.y * CHUNK, mini((ch.y + 1) * CHUNK, world_size.y)):
		for x in range(ch.x * CHUNK, mini((ch.x + 1) * CHUNK, world_size.x)):
			var c := Vector2i(x, y)
			if _taken.has(c):
				continue
			var got := _loot_at(c)
			if got.is_empty():
				continue
			var p := spawn_pickup(got[0], cell_center(c), got[1], holder)
			if p:
				p.set_meta("world_loot", true)
				p.tree_exiting.connect(_on_pickup_gone.bind(c, holder))


func _on_pickup_gone(cell: Vector2i, holder: Node) -> void:
	if is_instance_valid(holder) and not holder.has_meta("unloading"):
		_taken[cell] = true


## Objet posé sur une case (toujours le même pour une partie donnée) : [objet, quantité] ou [].
func _loot_at(c: Vector2i) -> Array:
	var i := _idx(c)
	var d := _decor[i]
	if d == D_OAK or d == D_PINE or d == D_BUSH or d == D_ROCK or d == D_IRON or d == D_GOLD:
		return []
	if Vector2(c - spawn_cell).length() < plaza_radius + 1:
		return []
	var t := _types[i]
	if t == WATER or t == DEEP:
		return []
	var r := _zone_type(_zone[i])
	var roll := _rand(c.x, c.y, 21)
	var chance := r.resource_chance if r else 0.01
	if roll < chance and r and not r.resources.is_empty():
		var it: ItemData = r.resources[int(_rand(c.x, c.y, 22) * r.resources.size()) % r.resources.size()]
		return [it, 1 + int(_rand(c.x, c.y, 23) * 2.5)]
	if roll < chance + wild_loot_chance and not wild_loot.is_empty() and t != SAND:
		return [wild_loot[int(_rand(c.x, c.y, 24) * wild_loot.size()) % wild_loot.size()], 1]
	if r == null:
		if t == STONE and roll < 0.02:
			return [iron_ore_item if roll < 0.008 else stone_item, 1]
		if t == GRASS and roll < 0.012:
			return [wood_item if roll < 0.008 else fiber_item, 1]
	return []


## Voyageurs déjà recrutés (clé de campement -> true).
var _recruited := {}

const OFFER_WISHES := {
	"forgeron": ["iron_ore", 4, "Je forge depuis vingt ans. Apporte-moi du minerai de fer et je te suivrai."],
	"macon": ["stone", 10, "Donne-moi de la bonne pierre et je te bâtirai des murs qui ne tombent jamais."],
	"bucheron": ["wood", 10, "Un peu de bois pour ma cognée, et je suis à toi."],
	"fermier": ["fiber", 6, "J'ai perdu mes semences sur la route... Tu aurais des fibres ?"],
	"garde": ["leather", 4, "Une armure de cuir neuve, et je défendrai ton village jusqu'à mon dernier souffle."],
	"tisserand": ["fiber", 8, "Avec des fibres, je te tisse ce que tu veux."],
	"verrier": ["stone", 6, "Le verre naît du sable et de la pierre. Montre-moi que tu en as."],
	"boulanger": ["wood", 6, "Il me faut du bois pour chauffer un four. Le pain suivra !"],
	"aubergiste": ["wood", 8, "Un village sans auberge, c'est triste. Aide-moi à en monter une."],
	"marchand": ["leather", 5, "Du cuir à revendre, et je t'ouvre mon réseau de commerce."],
	"erudit": ["fiber", 5, "Il me faut de quoi fabriquer du papier. Je sais lire les vieilles ruines."],
	"pretre": ["stone", 6, "Aide-moi à bâtir un autel et je bénirai ton village."],
	"mage": ["iron_ore", 3, "Le fer brut canalise la magie. Apporte-m'en et je t'enseignerai."],
	"chasseur": ["wood", 6, "Du bois pour tailler des pièges, et je ramènerai du gibier au village."],
	"pecheur": ["fiber", 6, "Des fibres pour tresser mes filets, et le poisson ne manquera plus."],
	"mineur": ["wood", 8, "Il me faut du bois pour étayer les galeries. Ensuite, la pierre est à toi."],
	"cuisinier": ["baies", 5, "Quelques baies pour goûter ta région, et je cuisinerai pour tout le monde."],
	"joaillier": ["iron_ore", 4, "Un peu de minerai pour mes outils : je saurai y trouver des éclats précieux."],
}


## Ce qu'un voyageur demande pour rejoindre le village.
func make_offer(job: String, lv: int) -> Dictionary:
	var wish: Array = OFFER_WISHES.get(job, ["wood", 6, "Je cherche un endroit sûr où vivre."])
	var items := []
	var it := Items.get_item(wish[0])
	if it:
		items.append([it, int(wish[1]) + lv / 2])
	var gold := Items.get_item("piece_or")
	if lv >= 5 and gold:
		items.append([gold, lv])
	return {"items": items, "text": wish[2]}


func _add_travelers(holder: Node3D, cell: Vector2i, z: Dictionary, trng: RandomNumberGenerator) -> void:
	var node := Node3D.new()
	node.name = "Voyageurs"
	holder.add_child(node)
	node.global_position = cell_center(cell)
	if campfire_scene:
		var fire := campfire_scene.instantiate() as Node3D
		node.add_child(fire)
	var plate := Label3D.new()
	plate.text = "Campement de voyageurs"
	plate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	plate.font_size = 44
	plate.pixel_size = 0.008
	plate.outline_size = 9
	plate.modulate = Color("ffe0a0")
	plate.position.y = 3.4
	node.add_child(plate)
	var r: RegionData = z.type
	var races: Array = r.recruit_races if r and not r.recruit_races.is_empty() else villager_races
	var n := trng.randi_range(1, 3)
	for i in n:
		var key := "%d,%d,%d" % [cell.x, cell.y, i]
		if _recruited.has(key) or villager_scene == null or races.is_empty():
			continue
		var v := villager_scene.instantiate() as Villager
		v.stranger = true
		v.race = races[trng.randi() % races.size()]
		v.villager_name = Villager.NAMES[trng.randi() % Villager.NAMES.size()]
		var lv: Vector2i = z.level
		v.level = trng.randi_range(lv.x, lv.y)
		var jobs := Villager.JOBS.duplicate()
		var j1: String = jobs[trng.randi() % jobs.size()]
		jobs.erase(j1)
		var j2: String = jobs[trng.randi() % jobs.size()]
		v.talents = {j1: trng.randf_range(0.45, 0.7), j2: trng.randf_range(0.15, 0.3)}
		v.recruit_offer = make_offer(j1, v.level)
		v.set_meta("recruit_key", key)
		v.wander_radius = 2.5
		var a := TAU * i / n + 0.4
		node.add_child(v)
		v.global_position = cell_center(cell) + Vector3(cos(a), 0, sin(a)) * 2.2
		v.home = v.global_position
		if trng.randf() < 0.7:
			_give_kit(v, Villager.class_kit(v.fight_class))


## Un voyageur a rejoint le village : il ne réapparaîtra plus dans son campement.
func mark_recruited(v: Node) -> void:
	if v.has_meta("recruit_key"):
		_recruited[v.get_meta("recruit_key")] = true


## Coffres ouverts dans le monde (châteaux, épaves) : identifiant -> vrai.
var opened_chests := {}
const GUARD_LINES := ["Halte ! ... Ah, un voyageur. Passe ton chemin en paix.", "Le seigneur reçoit dans le donjon.",
	"Rien à signaler sur les remparts.", "On raconte que des morts rôdent dans les châteaux abandonnés.", "Belle journée pour monter la garde."]


func _add_structure_content(holder: Node3D, st: Dictionary, center: Vector2i) -> void:
	var z: Dictionary = zones[int(st.zone)]
	var floor_y := float(st.get("base", roundi(terrain_height(center))))
	var pos := Vector3(center.x + 0.5, floor_y, center.y + 0.5)
	if st.kind == "wreck":
		_add_chest(holder, st.id, "wreck", pos + Vector3(0, 1.0, 0))
		return
	if st.kind == "sunken":
		var mid := pos
		_add_chest(holder, st.id, "sunken", pos + Vector3(0, 1.0, 0))
		# une bouée et son nom, à la surface : on la voit depuis le bateau
		var buoy := Label3D.new()
		buoy.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		buoy.text = "≈ %s ≈\ncité engloutie" % st.get("name", "Cité engloutie")
		buoy.font_size = 44
		buoy.pixel_size = 0.009
		buoy.outline_size = 10
		buoy.modulate = Color("8ad8ff")
		holder.add_child(buoy)
		buoy.global_position = Vector3(mid.x, water_surface + 3.0, mid.z)
		var glow := OmniLight3D.new()
		glow.light_color = Color("6ad0ff")
		glow.light_energy = 2.0
		glow.omni_range = 10.0
		holder.add_child(glow)
		glow.global_position = Vector3(mid.x, floor_y + 2.0, mid.z)
		return
	if st.abandoned:
		# château abandonné : les morts y montent la garde, le trésor dort dans le donjon
		var camp := EnemyCamp.new()
		camp.name = "MortsVivants"
		var types: Array[EnemyData] = [load("res://data/enemies/squelette.tres"), load("res://data/enemies/squelette.tres"),
			load("res://data/enemies/seigneur_squelette.tres")]
		camp.enemy_types = types
		camp.count = 5
		camp.levels = Vector2i((z.level as Vector2i).y, (z.level as Vector2i).y + 2)
		camp.base_level = 1
		camp.radius = 7.0
		holder.add_child(camp)
		camp.global_position = pos + Vector3(0, 0, 5)
		_add_chest(holder, st.id, "castle", pos)
	else:
		# château habité : une garnison et son seigneur
		var race := load("res://data/races/humain.tres") as RaceData
		for i in 4:
			var g := Townsfolk.new()
			g.name = "Garde_%d" % i
			g.race = race
			g.role = "guard"
			g.kit = ["sword_iron", "iron_helmet", "cape_red"]
			g.display_name = "Garde"
			g.lines = GUARD_LINES
			g.wander = 8.0
			g.home = pos + Vector3([-6, 6, -6, 6][i], 0, [-4, -4, 6, 6][i])
			holder.add_child(g)
			g.global_position = g.home
		var lord := Townsfolk.new()
		lord.name = "Seigneur"
		lord.race = race
		lord.role = "lord"
		lord.kit = ["cape_red"]
		lord.display_name = "Seigneur de %s" % z.name
		lord.color = Color("f2c86a")
		lord.lines = ["Bienvenue en mes terres, voyageur.", "Mes gens vivent en paix derrière ces murs.", "Les morts-vivants hantent les forts abandonnés : méfie-t'en."]
		lord.home = pos + Vector3(0, 0, 4.5)
		holder.add_child(lord)
		lord.global_position = lord.home


func _add_chest(holder: Node3D, id: String, kind: String, pos: Vector3) -> void:
	var c := WorldChest.new()
	c.chest_id = id
	c.kind = kind
	c.opened = opened_chests.has(id)
	holder.add_child(c)
	c.global_position = pos


func _add_camp(holder: Node3D, cell: Vector2i, z: Dictionary, crng: RandomNumberGenerator) -> void:
	var r: RegionData = z.type
	var camp := EnemyCamp.new()
	camp.name = "Camp"
	var pool: Array[EnemyData] = []
	var lv: Vector2i = z.level
	if r and not r.elite_enemies.is_empty() and crng.randf() < 0.1 + 0.25 * float(z.dist):
		pool.append(r.elite_enemies[crng.randi() % r.elite_enemies.size()])
		camp.count = 1
		lv = Vector2i(lv.y, lv.y + 1)
		# l'élite vient avec quelques monstres de la région
		if not r.enemies.is_empty() and crng.randf() < 0.6:
			var extra := EnemyCamp.new()
			extra.name = "Escorte"
			extra.enemy_types = [r.enemies[crng.randi() % r.enemies.size()]]
			extra.count = crng.randi_range(1, 2)
			extra.levels = z.level
			extra.base_level = r.level_range.x
			extra.radius = 3.5
			holder.add_child(extra)
			extra.global_position = cell_center(cell)
	elif r and not r.enemies.is_empty():
		pool.append(r.enemies[crng.randi() % r.enemies.size()])
		if crng.randf() < 0.4:
			pool.append(r.enemies[crng.randi() % r.enemies.size()])
		camp.count = crng.randi_range(monsters_per_camp.x, monsters_per_camp.y)
	else:
		var old := plains_enemies if _type(cell) != STONE else rock_enemies
		if old.is_empty():
			return
		pool.append(old[crng.randi() % old.size()])
		camp.count = crng.randi_range(monsters_per_camp.x, monsters_per_camp.y)
	camp.enemy_types = pool
	camp.levels = lv
	camp.base_level = r.level_range.x if r else 1
	holder.add_child(camp)
	camp.global_position = cell_center(cell)


func _add_obelisk(holder: Node3D, z: Dictionary) -> void:
	var body := StaticBody3D.new()
	body.name = "Obelisque"
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.2, 3.0, 1.2)
	cs.shape = box
	cs.position.y = 1.5
	body.add_child(cs)
	if obelisk_model:
		body.add_child(obelisk_model.instantiate())
	var light := OmniLight3D.new()
	light.light_color = Color("8af0ff")
	light.light_energy = 1.2
	light.omni_range = 5.0
	light.position.y = 3.2
	body.add_child(light)
	var label := Label3D.new()
	label.text = "Obélisque\n%s" % z.name
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 40
	label.pixel_size = 0.006
	label.outline_size = 10
	label.modulate = Color("bff6ff")
	label.position.y = 4.0
	label.no_depth_test = true
	body.add_child(label)
	holder.add_child(body)
	body.global_position = cell_center(z.obelisk)


## Hauteur du seuil de l'arche par rapport au sol de la case de la porte (fondations comprises).
func _gate_floor_offset(cell: Vector2i) -> float:
	var top := -100000
	for x in range(-2, 3):
		top = maxi(top, roundi(terrain_height(cell + Vector2i(x, 0))))
	return float(top) - terrain_height(cell)


func _add_gate(holder: Node3D, z: Dictionary) -> void:
	var body := StaticBody3D.new()
	body.name = "Donjon"
	# l'arche est faite de blocs (WorldStructures.gate_plan) ; dans l'ouverture, un voile de ténèbres
	var veil := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(1.0, 2.6)
	veil.mesh = qm
	var vm := StandardMaterial3D.new()
	vm.albedo_color = Color(0.05, 0.02, 0.08, 0.92)
	vm.emission_enabled = true
	vm.emission = Color(0.25, 0.08, 0.35)
	vm.emission_energy_multiplier = 0.6
	vm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	vm.cull_mode = BaseMaterial3D.CULL_DISABLED
	veil.material_override = vm
	veil.position = Vector3(0, 1.3 + _gate_floor_offset(z.gate), 0)
	body.add_child(veil)
	var label := Label3D.new()
	var dm := get_node_or_null("Donjons") as DungeonManager
	var gt: Array = dm.gate_text(z) if dm else [("Donjon de %s\nVaincu ✔" if z.get("cleared", false) else "Donjon de %s\nF : entrer") % z.name, Color("b0ffb0") if z.get("cleared", false) else Color("ffb0a0")]
	label.text = gt[0]
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 36
	label.pixel_size = 0.006
	label.outline_size = 10
	label.modulate = gt[1]
	label.position.y = 3.0
	body.add_child(label)
	holder.add_child(body)
	body.global_position = cell_center(z.gate)


# ---------------------------------------------------------------- constructions du monde (en blocs)

## Maisons et ruines des régions : [{"kind", "cell", "region", "seed"}].
var structure_sites: Array = []


## Choisit l'emplacement des maisons et des ruines (avant le premier affichage : le sol y est aplani).
func _plan_structures() -> void:
	structure_sites.clear()
	for z in zones:
		_progress(lerpf(0.75, 0.9, float(z.id) / zones.size()))
		if float(z.dist) == 0.0:
			continue
		var rid: String = (z.type as RegionData).id if z.type else "prairie"
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([world_seed, int(z.id), 77])
		for k in 2:
			var dir := Vector2.from_angle(rng.randf() * TAU)
			var c := _find_site(Vector2i((z.site as Vector2) + dir * (16.0 + 12.0 * k)), z.id, 30)
			if c.x < 0:
				continue
			var mid := c + Vector2i(2, 2)
			var ok := true
			for other in [z.obelisk, z.gate]:
				if (other as Vector2i).x >= 0 and mid.distance_to(other) < 9.0:
					ok = false
			for st in structure_sites:
				if mid.distance_to(st.cell) < 12.0:
					ok = false
			if not ok:
				continue
			_flatten_spot(mid, 4)
			structure_sites.append({"kind": "house" if k == 0 else "ruin", "cell": c, "region": rid, "seed": rng.randi()})
	# châteaux forts (environ une zone sur cinq, loin du village) et épaves échouées sur les côtes
	for z in zones:
		if float(z.dist) < 0.2:
			continue
		var rid: String = (z.type as RegionData).id if z.type else "prairie"
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([world_seed, int(z.id), 313])
		if rng.randf() < 0.2:
			var a0 := rng.randf() * TAU
			var c := Vector2i(-1, -1)
			var mid := c
			var ok := false
			for attempt in 8:
				var dir := Vector2.from_angle(a0 + attempt * TAU / 8.0)
				c = _find_site(Vector2i((z.site as Vector2) + dir * (30.0 + 6.0 * (attempt % 3))), z.id, 24)
				mid = c + Vector2i(10, 10)
				ok = _castle_spot_ok(c, mid, z)
				if ok:
					break
			if ok:
				_flatten_spot(mid, 12)
				var abandoned := rng.randf() < 0.55 or rid in ["volcan", "marais"]
				structure_sites.append({"kind": "castle", "cell": c, "region": rid, "seed": rng.randi(), "abandoned": abandoned,
					"id": "castle_%d" % int(z.id), "zone": int(z.id)})
		if rng.randf() < 0.15:
			var wc := _find_coast(Vector2i(z.site), int(z.id), 80)
			if wc.x >= 0:
				structure_sites.append({"kind": "wreck", "cell": wc, "region": rid, "seed": rng.randi(), "id": "wreck_%d" % int(z.id), "zone": int(z.id)})


func _castle_spot_ok(c: Vector2i, mid: Vector2i, z: Dictionary) -> bool:
	if c.x < 10 or c.y < 10 or c.x >= world_size.x - 32 or c.y >= world_size.y - 32:
		return false
	# tout le château sur la terre ferme
	for o in [Vector2i(0, 0), Vector2i(20, 0), Vector2i(0, 20), Vector2i(20, 20), Vector2i(10, 10), Vector2i(10, 0), Vector2i(0, 10), Vector2i(20, 10), Vector2i(10, 20)]:
		if not _is_dry_area(c + o, 2):
			return false
	for other in [z.obelisk, z.gate]:
		if (other as Vector2i).x >= 0 and mid.distance_to(other) < 18.0:
			return false
	for st in structure_sites:
		if mid.distance_to(st.cell) < 22.0:
			return false
	return true


# ---------------------------------------------------------------- routes et hameaux

## Routes pavées entre le village et les capitales : [[case, case, ...], ...] (points tous les ROAD_STEP mètres).
var roads: Array = []
var _bridges: Array = []
const ROAD_STEP := 6
## Hameaux le long des routes : un tous les ~HAMLET_EVERY mètres de route.
const HAMLET_EVERY := 170.0


## Relie le village et les capitales (arbre couvrant le plus court) par des routes qui évitent l'eau
## et les pentes raides (A* sur une grille de 6 m), puis les pave, les lisse et prévoit les ponts.
func _plan_roads() -> void:
	roads.clear()
	_bridges.clear()
	_road_cache.clear()
	var nodes: Array = [spawn_cell]
	for c in cities:
		nodes.append(c.center)
	if nodes.size() < 2:
		return
	# arbre couvrant minimal (Prim)
	var linked := [0]
	var edges: Array = []
	while linked.size() < nodes.size():
		var best := [-1, -1, INF]
		for i in linked:
			for j in nodes.size():
				if j in linked:
					continue
				var d := Vector2(nodes[i] - nodes[j]).length()
				if d < float(best[2]):
					best = [i, j, d]
		linked.append(best[1])
		edges.append([nodes[best[0]], nodes[best[1]]])
	for ei in edges.size():
		var e: Array = edges[ei]
		_progress(lerpf(0.3, 0.45, float(ei) / edges.size()))
		var path := _road_path(e[0], e[1])
		if path.size() >= 2:
			roads.append(path)
			_pave(path)


func _road_path(a: Vector2i, b: Vector2i) -> Array:
	var S := ROAD_STEP
	var start := Vector2i(a.x / S, a.y / S)
	var goal := Vector2i(b.x / S, b.y / S)
	var gw := world_size.x / S
	var gh := world_size.y / S
	var heap: Array = []
	var came := {start: start}
	var g := {start: 0.0}
	var closed := {}
	_heap_push(heap, [Vector2(start - goal).length(), 0, start])
	var seq := 0
	var found := false
	while not heap.is_empty():
		var cur: Vector2i = _heap_pop(heap)[2]
		if closed.has(cur):
			continue
		closed[cur] = true
		if cur == goal:
			found = true
			break
		var hc := _road_sample(cur, S).y
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
			var n: Vector2i = cur + d
			if n.x < 1 or n.y < 1 or n.x >= gw - 1 or n.y >= gh - 1 or closed.has(n):
				continue
			var cell := n * S
			var q := _road_sample(n, S)
			var t := int(q.x)
			var step := Vector2(d).length()
			var cost := step
			if t == WATER or t == DEEP:
				cost *= 7.0    # un pont, si vraiment il le faut
			else:
				var slope := absf(q.y - hc) / (S * step)
				cost *= 1.0 + slope * 40.0 + (25.0 if slope > 0.12 else 0.0)
			# on traverse les capitales par leurs rues, pas au travers des murs : on passe au large sauf au but
			var inside := city_at(Vector3(cell.x, 0, cell.y), 4.0)
			if not inside.is_empty() and Vector2(cell - b).length() > float(inside.radius) + 6.0 and Vector2(cell - a).length() > float(inside.radius) + 6.0:
				cost *= 20.0
			var ng: float = float(g[cur]) + cost
			if not g.has(n) or ng < float(g[n]):
				g[n] = ng
				came[n] = cur
				seq += 1
				_heap_push(heap, [ng + Vector2(n - goal).length(), seq, n])
	if not found:
		return []
	var path: Array = [goal * S]
	var c: Vector2i = goal
	while c != start:
		c = came[c]
		path.push_front(c * S)
	return path


## Terrain d'un point de la grille des routes : celui déjà calculé, sinon une estimation rapide (et mise en cache).
var _road_cache := {}


func _road_sample(g: Vector2i, S: int) -> Vector2:
	if _road_cache.has(g):
		return _road_cache[g]
	var cell := g * S
	var out: Vector2
	var ch := _chunk_of(cell)
	if _inside(cell) and _chunk_ready[ch.y * _chunks.x + ch.x] != 0:
		out = Vector2(_types[_idx(cell)], _heights[_idx(cell)])
	else:
		out = _quick_cell(cell.x, cell.y)
	_road_cache[g] = out
	return out


## Pave une route : 3 cases de large, hauteur lissée d'un point à l'autre (on y marche partout), ponts sur l'eau.
func _pave(path: Array) -> void:
	for i in path.size() - 1:
		var a: Vector2i = path[i]
		var b: Vector2i = path[i + 1]
		var ha := _h(a)
		var hb := _h(b)
		var n := maxi(1, int(Vector2(b - a).length()))
		for k in n + 1:
			var t := float(k) / n
			var p := Vector2(a).lerp(Vector2(b), t)
			var hgt := snappedf(lerpf(ha, hb, t), step_height)
			for oy in range(-1, 2):
				for ox in range(-1, 2):
					var c := Vector2i(roundi(p.x) + ox, roundi(p.y) + oy)
					if not _inside(c):
						continue
					if not city_at(Vector3(c.x, 0, c.y), 0.0).is_empty():
						continue    # les rues de la ville prennent le relais
					if Vector2(c - spawn_cell).length() <= spawn_clearing_radius:
						continue
					_ensure_chunk_of(c)
					var idx := _idx(c)
					if _types[idx] == WATER or _types[idx] == DEEP:
						_bridges.append(c)
						continue
					_decor[idx] = D_NONE
					_types[idx] = PLAZA
					if ha > SEA_FLOOR and hb > SEA_FLOOR:
						_heights[idx] = maxf(hgt, 0.0)


## Les ponts de planches au-dessus des rivières traversées par les routes.
func _build_bridges() -> void:
	if build == null or _bridges.is_empty():
		return
	build.generating = true
	var plank := Items.get_item("bloc_planches")
	var post := Items.get_item("bloc_rondins")
	for c in _bridges:
		build.place_block(Vector3i(c.x, -1, c.y), plank)
	# des rambardes de rondins sur les bords
	var set := {}
	for c in _bridges:
		set[c] = true
	for c in _bridges:
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			var t := _type(n)
			if not set.has(n) and (t == WATER or t == DEEP) and (c.x + c.y) % 2 == 0:
				build.place_block(Vector3i(c.x, 0, c.y), post)
				break
	build.generating = false
	build.changed.emit()


## Vrai si la case est sur une route pavée (ou un pont).
func on_road(cell: Vector2i) -> bool:
	return _inside(cell) and _types[_idx(cell)] == PLAZA and city_at(Vector3(cell.x, 0, cell.y), 2.0).is_empty() \
		and Vector2(cell - spawn_cell).length() > plaza_radius + 2


## Hameaux : quelques maisons autour d'une petite place, au bord des routes, tous les ~170 m.
func _plan_hamlets() -> void:
	var n := 0
	for path in roads:
		var walked := HAMLET_EVERY * 0.6
		for i in range(1, path.size() - 1):
			walked += Vector2(path[i] - path[i - 1]).length()
			if walked < HAMLET_EVERY:
				continue
			var a: Vector2i = path[i]
			var dir := Vector2(path[i + 1] - path[i - 1]).normalized()
			var side := Vector2(-dir.y, dir.x) * (1.0 if (i / 3) % 2 == 0 else -1.0)
			var c := a + Vector2i(roundi(side.x * 15.0), roundi(side.y * 15.0))
			if not _hamlet_spot_ok(c):
				continue
			walked = 0.0
			var zid := _zone[_idx(c)]
			var z: Dictionary = zones[zid]
			var rid: String = (z.type as RegionData).id if z.type else "prairie"
			var rng := RandomNumberGenerator.new()
			rng.seed = hash([world_seed, c.x, c.y, 515])
			_flatten_spot(c, 13)
			var id := "hamlet_%d" % n
			n += 1
			var nearest := ""
			var nd := INF
			for city in cities:
				var d := Vector2(c - (city.center as Vector2i)).length()
				if d < nd:
					nd = d
					nearest = city.nation
			var hname := "%s%s" % [NAME_START[rng.randi() % NAME_START.size()], NAME_END[rng.randi() % NAME_END.size()]]
			structure_sites.append({"kind": "hamlet", "cell": c, "region": rid, "seed": rng.randi(), "id": id, "zone": zid,
				"name": hname, "nation": nearest})
			# ses maisons, au nord de la place (porte vers la place) et au sud
			var count := rng.randi_range(4, 6)
			for k in count:
				var hx := -11 + (k % 3) * 8
				var hz := -10 if k < 3 else 5
				structure_sites.append({"kind": "house", "cell": c + Vector2i(hx, hz), "region": rid, "seed": rng.randi(), "hamlet": id})


## Cités englouties : 3 à 5 ruines au fond de la mer, là où l'eau est profonde sur toute leur emprise.
const SUNKEN_MAX := 5
func _plan_sunken() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([world_seed, 717])
	var cands := []
	var step := 23
	for gy in range(20, world_size.y - 36, step):
		for gx in range(20, world_size.x - 36, step):
			var c := Vector2i(gx + rng.randi_range(-6, 6), gy + rng.randi_range(-6, 6))
			if _sunken_spot_ok(c):
				cands.append(c)
	# mélange déterministe (le monde doit être le même à chaque chargement)
	for i in range(cands.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = cands[i]
		cands[i] = cands[j]
		cands[j] = tmp
	var picked := []
	for c in cands:
		if picked.size() >= SUNKEN_MAX:
			break
		var ok := true
		for o in picked:
			if Vector2(c - (o as Vector2i)).length() < 220.0:
				ok = false
				break
		if not ok:
			continue
		picked.append(c)
		var zid := _zone[_idx(c + Vector2i(7, 7))]
		var z: Dictionary = zones[zid]
		structure_sites.append({"kind": "sunken", "cell": c, "region": (z.type as RegionData).id if z.type else "prairie",
			"seed": rng.randi(), "id": "sunken_%d" % picked.size(), "zone": zid, "name": SUNKEN_NAMES[(picked.size() - 1) % SUNKEN_NAMES.size()]})


const SUNKEN_NAMES := ["Ys la Noyée", "Thalassor", "Atlantée", "Corail-des-Rois", "Vel-Marin"]


func _sunken_spot_ok(c: Vector2i) -> bool:
	if not _inside(c) or not _inside(c + Vector2i(15, 15)):
		return false
	for z in range(-3, 18, 3):
		for x in range(-3, 18, 3):
			if _type(c + Vector2i(x, z)) != DEEP:
				return false
	if not island_of(Vector2i((c.x + 7) / ISLAND_GRID, (c.y + 7) / ISLAND_GRID)).is_empty():
		return false
	for st in structure_sites:
		if Vector2(c - (st.cell as Vector2i)).length() < 60.0:
			return false
	return true


func _hamlet_spot_ok(c: Vector2i) -> bool:
	if not _inside(c) or c.x < 20 or c.y < 20 or c.x >= world_size.x - 20 or c.y >= world_size.y - 20:
		return false
	if Vector2(c - spawn_cell).length() < 110.0 or not city_at(Vector3(c.x, 0, c.y), 60.0).is_empty():
		return false
	for o in [Vector2i(0, 0), Vector2i(-12, -10), Vector2i(12, -10), Vector2i(-12, 10), Vector2i(12, 10)]:
		var t := _type(c + o)
		if t == WATER or t == DEEP or t == PLAZA:
			return false
		if absf(_h(c + o) - _h(c)) > 2.5:
			return false
	for st in structure_sites:
		if Vector2(c - (st.cell as Vector2i)).length() < (120.0 if st.kind == "hamlet" else 24.0):
			return false
	for z in zones:
		if (z.obelisk as Vector2i).x >= 0 and Vector2(c - (z.obelisk as Vector2i)).length() < 16.0:
			return false
		if (z.gate as Vector2i).x >= 0 and Vector2(c - (z.gate as Vector2i)).length() < 16.0:
			return false
	return true


## Les habitants d'un hameau : quelques villageois, un colporteur et le chef (qui a souvent une quête).
func _add_hamlet_content(holder: Node3D, st: Dictionary) -> void:
	var c: Vector2i = st.cell
	var rng := RandomNumberGenerator.new()
	rng.seed = int(st.seed)
	var races: Array = CityPlans.CITIES.get(st.nation, {}).get("races", ["humain"])
	var cl := get_tree().get_first_node_in_group("city_life")
	var plate := Label3D.new()
	plate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	var ravaged: bool = st.get("ravaged", false)
	plate.text = "Hameau de %s%s" % [st.name, "\n(ravagé par les morts)" if ravaged else ("\n" + str(Diplomacy.NATIONS.get(st.nation, {}).get("name", "")) if st.has("born") else "")]
	plate.font_size = 44
	plate.pixel_size = 0.008
	plate.outline_size = 10
	plate.modulate = Color("f2dca0")
	holder.add_child(plate)
	plate.global_position = cell_center(c) + Vector3(0, 4.0, 0)
	for k in 6:
		var t := Townsfolk.new()
		t.race = load("res://data/races/%s.tres" % races[rng.randi() % races.size()]) as RaceData
		t.name = "Hameau_%d" % k
		t.home = cell_center(c + Vector2i(rng.randi_range(-6, 6), rng.randi_range(-3, 3)))
		t.display_name = CityLife.random_name(st.nation, rng) if cl else "Villageois"
		t.lines = ["Bienvenue à %s, voyageur." % st.name, "La route est longue jusqu'à la capitale.", "Méfie-toi des bandits sur les routes, la nuit."]
		if ravaged:
			t.lines = ["Les morts sont venus de la nuit... ils ont tout pris.", "On rebâtira. Il faut bien.", "Le château abandonné... on aurait dû s'en méfier."]
		elif st.has("born") and st.born != st.nation:
			t.lines = ["Nous avons changé de bannière : %s tient le hameau, maintenant." % Diplomacy.NATIONS.get(st.nation, {}).get("name", ""),
				"Les soldats sont passés par ici. On fait profil bas.", "Bienvenue à %s, voyageur." % st.name]
		t.wander = 7.0
		match k if not ravaged else -1:
			0:
				t.role = "merchant"
				t.trade_name = "Colporteur"
				t.color = Color("ffe08a")
				var trade := get_tree().get_first_node_in_group("trade") as Trade
				if trade:
					if not st.has("shop"):
						st["shop"] = CityMerchant.new(trade, {"name": st.name, "nation": st.nation}, ["Épicier", "Herboriste", "Charpentier"][rng.randi() % 3], t.display_name, rng)
					t.shop = st.shop
					t.trade_name = "Colporteur (%s)" % (st.shop as CityMerchant).trade_name.to_lower()
				t.home = cell_center(c + Vector2i(0, -2))
			1:
				t.display_name = "Chef " + t.display_name
				t.color = Color("f2c86a")
				t.quest_key = "hamlet:" + str(st.id)
				t.home = cell_center(c + Vector2i(2, 1))
		holder.add_child(t)
		t.global_position = t.home
		if t.quest_key != "" and cl:
			cl._refresh_mark(t)


# ---------------------------------------------------------------- capitales

## Les capitales des nations voisines (voir CityPlans) : {nation, name, center, base, radius, population, races,
## stalls, streets, gates, hall, seed}. Leurs blocs sont posés par _build_cities.
var cities: Array = []
var _city_plans := {}


## La capitale qui contient `pos` (à `margin` mètres près), ou {}.
func city_at(pos: Vector3, margin := 0.0) -> Dictionary:
	for c in cities:
		var ctr: Vector2i = c.center
		if Vector2(pos.x - ctr.x, pos.z - ctr.y).length() <= float(c.radius) + margin:
			return c
	return {}


## Choisit où bâtir les cinq capitales (dans les régions de leur peuple, loin du village et les unes des autres,
## sur un terrain sec et pas trop accidenté) puis façonne leur relief.
func _plan_cities() -> void:
	cities.clear()
	_city_plans.clear()
	var ni := 0
	for nation in CityPlans.CITIES:
		_progress(lerpf(0.08, 0.3, float(ni) / CityPlans.CITIES.size()), "Fondation de %s..." % CityPlans.CITIES[nation].name)
		ni += 1
		var info: Dictionary = CityPlans.CITIES[nation]
		var r := int(info.radius)
		var margin := r + 16
		var best := Vector2i(-1, -1)
		var best_score := -INF
		# d'abord les régions du peuple de la nation ; les autres seulement si aucune ne convient
		# (évaluer tout le monde obligerait à calculer le terrain de 2 km² dès le départ)
		for pass_i in 2:
			if best.x >= 0:
				break
			for z in zones:
				if float(z.dist) < 0.3:
					continue
				var rid: String = (z.type as RegionData).id if z.type else "prairie"
				var pref := (info.regions as Array).find(rid)
				if (pass_i == 0) != (pref >= 0):
					continue
				var cand := _city_candidate(z, info.regions, r, margin)
				if cand.size() == 2 and float(cand[1]) > best_score:
					best_score = float(cand[1])
					best = cand[0]
		if best.x < 0:
			continue
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([world_seed, nation, 4011])
		var city_seed := rng.seed
		var plan := CityPlans.plan(nation, rng)
		var city := {"nation": nation, "name": info.name, "center": best, "radius": r, "population": int(info.population),
			"races": info.races, "stalls": plan.stalls, "streets": plan.streets, "gates": plan.gates, "hall": plan.hall,
			"seed": city_seed, "style": info.style, "houses": plan.houses}
		_shape_city(city, plan)
		_city_plans[nation] = plan
		cities.append(city)


## Le meilleur emplacement de capitale autour du cœur d'une zone : [case, score] ou [].
func _city_candidate(z: Dictionary, regions: Array, r: int, margin: int) -> Array:
	var best: Array = []
	for off in [Vector2i.ZERO, Vector2i(32, 0), Vector2i(-32, 0), Vector2i(0, 32), Vector2i(0, -32),
			Vector2i(32, 32), Vector2i(-32, 32), Vector2i(32, -32), Vector2i(-32, -32)]:
		var c: Vector2i = Vector2i(z.site) + off
		if c.x < margin or c.y < margin or c.x >= world_size.x - margin or c.y >= world_size.y - margin:
			continue
		if Vector2(c - spawn_cell).length() < r + 160:
			continue
		var far := true
		for o in cities:
			if Vector2(c - (o.center as Vector2i)).length() < r + int(o.radius) + 80:
				far = false
		if not far:
			continue
		# la région au centre même de la ville (le cœur de la zone peut être à la frontière)
		var zr := _zone_type(_nearest_zones(c.x, c.y)[0])
		var pref := regions.find(zr.id if zr else "prairie")
		var site := _city_site_quality(c, r + 6, pref == 0)
		if site.x < 0.0:
			continue
		var score := (40.0 if pref == 0 else (30.0 if pref > 0 else 0.0)) - site.y * 0.5 - absf(float(z.dist) - 0.6) * 4.0 \
			+ _rand(int(z.id), off.x + 3 * off.y, 77) * 0.5
		if best.is_empty() or score > float(best[1]):
			best = [c, score]
	return best


## x : -1 si l'endroit ne convient pas (trop d'eau ou de relief) ; y : sa pénalité (relief, part d'eau).
func _city_site_quality(c: Vector2i, r: int, lenient := false) -> Vector2:
	var lo := INF
	var hi := -INF
	var wet := 0
	var n := 0
	for y in range(-r, r + 1, 9):
		for x in range(-r, r + 1, 9):
			if Vector2(x, y).length() > r:
				continue
			var cell := c + Vector2i(x, y)
			n += 1
			var q := _quick_cell(cell.x, cell.y)
			var t := int(q.x)
			if t == WATER or t == DEEP:
				wet += 1
				continue
			lo = minf(lo, q.y)
			hi = maxf(hi, q.y)
	# dans la région préférée de la nation, on accepte un terrain plus difficile (la ville le façonne)
	if n == 0 or wet > n * (0.4 if lenient else 0.2) or hi - lo > (36.0 if lenient else 30.0):
		return Vector2(-1, 0)
	# la ville comble l'eau de son emprise, mais mieux vaut peu d'eau et peu de relief
	return Vector2(1, hi - lo + 60.0 * wet / n)


## Aplani la ville au niveau moyen du terrain, y ajoute son relief (collines, terrasses), pave les rues
## et adoucit les abords jusqu'au terrain naturel.
func _shape_city(city: Dictionary, plan: Dictionary) -> void:
	var ctr: Vector2i = city.center
	var R: int = city.radius
	var sum := 0.0
	var n := 0
	for y in range(-R, R + 1, 4):
		for x in range(-R, R + 1, 4):
			if Vector2(x, y).length() <= R:
				var t := _type(ctr + Vector2i(x, y))
				if t != WATER and t != DEEP:
					sum += _h(ctr + Vector2i(x, y))
					n += 1
	var base := roundi(sum / maxf(1.0, n))
	city["base"] = base
	var ground := SAND if city.style == "harad" else GRASS
	# des abords d'autant plus longs que le terrain autour est accidenté (pente de marche)
	var rough := 0.0
	for k in 24:
		var a := TAU * k / 24.0
		var c := ctr + Vector2i(roundi(cos(a) * (R + 20)), roundi(sin(a) * (R + 20)))
		if _inside(c) and _type(c) != WATER and _type(c) != DEEP:
			rough = maxf(rough, absf(_h(c) - base))
	var blend := clampi(int(rough * 2.2), 16, 44)
	for y in range(-R - blend - 2, R + blend + 3):
		for x in range(-R - blend - 2, R + blend + 3):
			var c := ctr + Vector2i(x, y)
			if not _inside(c):
				continue
			_ensure_chunk_of(c)
			var i := _idx(c)
			var d := Vector2(x, y).length()
			if d <= R + 2:
				_heights[i] = base + float(plan.relief.get(Vector2i(x, y), 0.0))
				_types[i] = ground
				_decor[i] = D_NONE
			elif d <= R + 2 + blend:
				if _types[i] == WATER or _types[i] == DEEP:
					continue
				var k := (d - R - 2) / float(blend)
				_heights[i] = snappedf(lerpf(base, _heights[i], k), step_height)
				if k < 0.5:
					_decor[i] = D_NONE
	# une rampe pavée devant chaque porte de l'enceinte : on entre toujours à pied, même en montagne
	for g in plan.gates:
		var gv := Vector2(g)
		if gv.length() < R - 12:
			continue
		var dir := gv.normalized()
		var side := Vector2(-dir.y, dir.x)
		var length := blend + 14
		var end_cell := ctr + Vector2i((gv + dir * length).round())
		# devant un lac (ou une coulée de lave), la rampe devient une chaussée jusqu'à la terre ferme
		while length < blend + 70 and _inside(end_cell) and (_type(end_cell) == WATER or _type(end_cell) == DEEP):
			length += 4
			end_cell = ctr + Vector2i((gv + dir * length).round())
		var start_h := base + float(plan.relief.get(g, 0.0))
		var end_h := maxf(_h(end_cell), 0.25)
		for k in range(1, length + 1):
			var hk := snappedf(lerpf(start_h, end_h, float(k) / length), step_height)
			for w2 in range(-2, 3):
				var p2 := gv + dir * k + side * w2
				var c2 := ctr + Vector2i(p2.round())
				if not _inside(c2):
					continue
				_ensure_chunk_of(c2)
				var i2 := _idx(c2)
				_heights[i2] = maxf(hk, 0.25)
				_types[i2] = PLAZA
				_decor[i2] = D_NONE
	# rues pavées : chaque point de passage et ses voisins
	for s in plan.streets:
		for o in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var c: Vector2i = ctr + (s as Vector2i) + o
			if _inside(c):
				_types[_idx(c)] = PLAZA


## Pose les blocs des capitales (même mécanisme que les autres constructions : destructibles, sauvegardés en différence).
func _build_cities() -> void:
	if build == null:
		return
	build.generating = true
	var items := {}
	for city in cities:
		var plan: Dictionary = _city_plans.get(city.nation, {})
		if plan.is_empty():
			continue
		var ctr: Vector2i = city.center
		var base: int = city.base
		var n := 0
		for k in plan.blocks:
			var id: String = plan.blocks[k]
			if not items.has(id):
				items[id] = Items.get_item(id)
			if build.place_block(Vector3i(ctr.x + k.x, base + k.y, ctr.y + k.z), items[id]):
				n += 1
		city["blocks"] = n
	_city_plans.clear()
	build.generating = false
	build.changed.emit()


## Une plage de sable au bord de l'eau, près de `from` (dans la zone), pour une épave.
func _find_coast(from: Vector2i, zone_id: int, max_r: int) -> Vector2i:
	for r in range(6, max_r, 3):
		for i in 24:
			var a := TAU * i / 24.0
			var c := from + Vector2i(roundi(cos(a) * r), roundi(sin(a) * r))
			if not _inside(c) or c.x < 6 or c.y < 6 or c.x >= world_size.x - 16 or c.y >= world_size.y - 16:
				continue
			if _type(c) != SAND or _zone[_idx(c)] != zone_id:
				continue
			if not city_at(Vector3(c.x, 0, c.y), 10.0).is_empty():
				continue
			for d in [Vector2i(3, 0), Vector2i(-3, 0), Vector2i(0, 3), Vector2i(0, -3)]:
				var t := _type(c + d)
				if t == WATER or t == DEEP:
					return c
	return Vector2i(-1, -1)


## Pose les blocs de toutes les constructions du monde (une partie chargée les remplace ensuite
## par les blocs sauvegardés : ce qui a été cassé le reste).
func _build_structures() -> void:
	if build == null:
		return
	build.generating = true
	for st in structure_sites:
		if st.kind == "hamlet":
			continue    # ses maisons sont des sites « house » à part
		var style: Dictionary = WorldStructures.STYLES.get(st.region, WorldStructures.STYLES.prairie)
		var rng := RandomNumberGenerator.new()
		rng.seed = int(st.seed)
		var plan: Dictionary
		var broken := 0.0
		match st.kind:
			"house":
				plan = WorldStructures.house_plan(style)
				broken = 0.08
			"ruin":
				plan = WorldStructures.ruin_plan(style, rng)
			"castle":
				var mats: Array = WorldStructures.CASTLE_MATS.get(st.region, ["bloc_briques", "bloc_pierre_polie"])
				plan = WorldStructures.castle_plan(21, 5, mats[0], mats[1])
				broken = 0.22 if st.abandoned else 0.0
				style = {}
			"wreck":
				plan = WorldStructures.shipwreck_plan(rng)
				style = {}
			"sunken":
				plan = WorldStructures.sunken_plan(rng)
				style = {}
		_clear_decor_under(plan, st.cell)
		if st.kind == "castle":
			# la cour aussi : pas d'arbres dans l'enceinte
			for y in 21:
				for x in 21:
					_clear_decor_cell(st.cell + Vector2i(x, y))
		WorldStructures.build(self, plan, st.cell, rng, broken, style)
		st["base"] = WorldStructures.last_base
	for z in zones:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([world_seed, int(z.id), 91])
		if (z.gate as Vector2i).x >= 0:
			var gp := WorldStructures.gate_plan()
			_clear_decor_under(gp, z.gate)
			WorldStructures.build(self, gp, z.gate, rng, 0.0, {})
		if (z.obelisk as Vector2i).x >= 0:
			var op := WorldStructures.obelisk_plan()
			_clear_decor_under(op, z.obelisk)
			WorldStructures.build(self, op, z.obelisk, rng)
	build.generating = false
	build.changed.emit()


func _clear_decor_under(plan: Dictionary, origin: Vector2i) -> void:
	for k in plan:
		_clear_decor_cell(Vector2i(origin.x + k.x, origin.y + k.z))


func _clear_decor_cell(c: Vector2i) -> void:
	if not _inside(c):
		return
	_ensure_chunk_of(c)
	if _decor[_idx(c)] != D_NONE:
		_decor[_idx(c)] = D_NONE
		if _decor_nodes.has(_chunk_of(c)):
			_build_decor_chunk(_chunk_of(c))


# ---------------------------------------------------------------- carte

## Couleur d'une case sur la carte (relief éclairé du nord-ouest).
func map_color(cell: Vector2i) -> Color:
	var t := _type(cell)
	var c := _top_color(cell)
	if t == WATER or t == DEEP:
		var r := _zone_type(_zone[_idx(cell)])
		if r and r.liquid_color.a > 0.0:
			c = r.liquid_color
		else:
			c = Color(0.25, 0.5, 0.8).darkened(0.25 if t == DEEP else 0.0)
	else:
		var slope := _h(cell) - _h(cell + Vector2i(-1, -1))
		c = c.lightened(clampf(slope * 0.25, 0.0, 0.3)) if slope > 0 else c.darkened(clampf(-slope * 0.25, 0.0, 0.3))
	if build and not build.column(cell).is_empty():
		c = Color("c8a070")
	return c


## Dévoile la carte autour d'une position.
func reveal(pos: Vector3, radius: int) -> void:
	if map_image == null:
		return
	_last_reveal = pos
	var c := cell_at(pos)
	var r2 := radius * radius
	for y in range(c.y - radius, c.y + radius + 1):
		for x in range(c.x - radius, c.x + radius + 1):
			var dx := x - c.x
			var dy := y - c.y
			if dx * dx + dy * dy > r2:
				continue
			var cell := Vector2i(x, y)
			if not _inside(cell):
				continue
			var i := _idx(cell)
			if _revealed[i] != 0:
				continue
			_revealed[i] = 1
			map_image.set_pixelv(cell, map_color(cell))
	_map_dirty = true


func is_revealed(cell: Vector2i) -> bool:
	return _inside(cell) and _revealed[_idx(cell)] != 0


## Redessine des cases de la carte (après une construction ou un terrassement).
func refresh_map(cells: Array) -> void:
	if map_image == null:
		return
	for c in cells:
		if is_revealed(c):
			map_image.set_pixelv(c, map_color(c))
	_map_dirty = true


# ---------------------------------------------------------------- sauvegarde

## Un drapeau du royaume est planté quelque part.
func has_home() -> bool:
	return home_cell.x >= 0


## Case du centre du camp : le drapeau ; arraché, le dernier endroit où il était ; jamais planté, l'arrivée.
func home_cell_or_spawn() -> Vector2i:
	if has_home():
		return home_cell
	if _last_home.x >= 0:
		return _last_home
	return spawn_cell


## Centre du camp en 3D (voir home_cell_or_spawn).
func home_center() -> Vector3:
	return cell_center(home_cell_or_spawn())


## Rayon de la zone du camp (m) selon le rang du royaume : Campement, Hameau, Village, Bourg, Ville, Cité, Capitale.
const HOME_RADII := [16.0, 20.0, 26.0, 32.0, 40.0, 50.0, 62.0]


func home_radius() -> float:
	var k := get_tree().get_first_node_in_group("kingdom") if is_inside_tree() else null
	return HOME_RADII[clampi(int(k.rank) if k else 0, 0, HOME_RADII.size() - 1)]


## Ce point est dans la zone du camp (drapeau planté).
func in_home_zone(pos: Vector3) -> bool:
	if not has_home():
		return false
	var c := home_center()
	return Vector2(pos.x - c.x, pos.z - c.z).length() <= home_radius()


## Le foyer du camp, où les habitants se retrouvent (repas, veillées) : le feu de camp du départ s'il est près du
## drapeau, sinon un feu de camp posé dans la zone, sinon le drapeau lui-même.
func hearth_center() -> Vector3:
	var home := home_center()
	var r := 16.0 if not is_inside_tree() else home_radius()
	if not GameState.bare_start and cell_center(spawn_cell).distance_to(home) <= r:
		return cell_center(spawn_cell)
	var best := home
	var best_d := r
	if build:
		for k in build.furniture:
			var f: Dictionary = build.furniture[k]
			if (f.item as ItemData).id == "feu_de_camp":
				var pos := Vector3(f.col.x + 0.5, f.base, f.col.y + 0.5)
				var d := pos.distance_to(home)
				if d < best_d:
					best_d = d
					best = pos
	return best


## Le drapeau vient d'être planté dans cette case (BuildGrid l'appelle).
func set_home(c: Vector2i) -> void:
	if c == home_cell:
		return
	home_cell = c
	_last_home = c
	home_changed.emit()


## Le drapeau vient d'être arraché : plus de camp (ni de raids) tant qu'il n'est pas replanté.
func clear_home() -> void:
	if not has_home():
		return
	home_cell = Vector2i(-1, -1)
	home_changed.emit()


## Ancienne sauvegarde (avant le drapeau) : le village était à l'arrivée, on y plante le drapeau.
func plant_legacy_flag() -> void:
	var it := Items.get_item(FLAG_ID) as ItemData
	for r in range(2, 8):
		for i in 12:
			var a := TAU * i / 12.0
			var c := spawn_cell + Vector2i(roundi(cos(a) * r), roundi(sin(a) * r))
			if it and village_prop_at(c, terrain_height(c)) == null and build.place_furniture(c, terrain_height(c), it, 0):
				return
	set_home(spawn_cell)


## État du monde qui ne se recalcule pas à partir de la graine.
func export_state() -> Dictionary:
	var edits := []
	for c in _edits:
		var e: Array = _edits[c]
		edits.append([c.x, c.y, e[0], e[1], e[2]])
	var taken := []
	for c in _taken:
		taken.append([c.x, c.y])
	var zs := []
	for z in zones:
		zs.append([1 if z.discovered else 0, 1 if z.obelisk_on else 0, 1 if z.get("cleared", false) else 0, int(z.get("brume", 0))])
	return {
		"seed": world_seed, "size": [world_size.x, world_size.y], "edits": edits, "taken": taken, "recruited": _recruited.keys(), "zones": zs,
		"flag_v": 1, "last_home": [_last_home.x, _last_home.y],
		"removed_props": removed_props.keys(), "chests": opened_chests.keys(),
		"revealed": Marshalls.raw_to_base64(_revealed.compress(FileAccess.COMPRESSION_ZSTD)),
		"map": Marshalls.raw_to_base64(map_image.save_png_to_buffer()),
	}


func import_state(d: Dictionary) -> void:
	# le drapeau se replante avec les meubles (BuildGrid rappelle set_home)
	home_cell = Vector2i(-1, -1)
	var lh: Array = d.get("last_home", [-1, -1])
	_last_home = Vector2i(int(lh[0]), int(lh[1]))
	opened_chests.clear()
	for id in d.get("chests", []):
		opened_chests[str(id)] = true
	if is_inside_tree():
		for c in get_tree().get_nodes_in_group("world_chests"):
			c.opened = opened_chests.has(c.chest_id)
			c._refresh()
	for e in d.get("edits", []):
		var c := Vector2i(int(e[0]), int(e[1]))
		if not _inside(c):
			continue
		_ensure_chunk_of(c)
		var i := _idx(c)
		_heights[i] = float(e[2])
		_types[i] = int(e[3])
		_decor[i] = int(e[4])
		_edits[c] = [float(e[2]), int(e[3]), int(e[4])]
	for t in d.get("taken", []):
		_taken[Vector2i(int(t[0]), int(t[1]))] = true
	for k in d.get("recruited", []):
		_recruited[k] = true
	for id in d.get("removed_props", []):
		var n := village_prop(str(id))
		if n:
			n.free()
		_village_props.erase(str(id))
		removed_props[str(id)] = true
	var zs: Array = d.get("zones", [])
	for i in mini(zs.size(), zones.size()):
		zones[i].discovered = int(zs[i][0]) == 1
		zones[i].obelisk_on = int(zs[i][1]) == 1
		zones[i].cleared = int(zs[i][2]) == 1
		zones[i].brume = int(zs[i][3]) if (zs[i] as Array).size() > 3 else 0
	if d.has("revealed"):
		var raw := Marshalls.base64_to_raw(d.revealed).decompress(_revealed.size(), FileAccess.COMPRESSION_ZSTD)
		if raw.size() == _revealed.size():
			_revealed = raw
	if d.has("map"):
		var img := Image.new()
		if img.load_png_from_buffer(Marshalls.base64_to_raw(d.map)) == OK:
			img.convert(Image.FORMAT_RGBA8)
			map_image = img
			map_texture.set_image(map_image)
	# on redessine ce qui est déjà affiché avec les modifications
	for ch in _terrain_nodes.keys():
		_build_terrain_chunk(ch)
		_build_decor_chunk(ch)
	for ch in _content_nodes.keys():
		refresh_content(Vector2i(ch.x * CHUNK, ch.y * CHUNK))
	current_zone = -1


## Recrée le contenu (camps, objets, lieux) du morceau de cette case, s'il est affiché.
func refresh_content(cell: Vector2i) -> void:
	var ch := _chunk_of(cell)
	if not _content_nodes.has(ch):
		return
	var holder: Node = _content_nodes[ch]
	if is_instance_valid(holder):
		holder.set_meta("unloading", true)
		holder.queue_free()
	_content_nodes.erase(ch)
	_build_content(ch)


## Affiche tout de suite les morceaux autour d'une position (avant une téléportation).
func load_area(pos: Vector3) -> void:
	if _generated:
		_stream(pos, true)


## Téléporte le héros n'importe où (terminal de commandes) : au sol, ou sur les blocs de la case.
func teleport(pos: Vector3) -> void:
	if player == null:
		return
	var c := cell_at(pos)
	if not _inside(c):
		c = Vector2i(clampi(c.x, 1, world_size.x - 2), clampi(c.y, 1, world_size.y - 2))
	var dest := Vector3(c.x + 0.5, 0.0, c.y + 0.5)
	_stream(dest, true)
	dest.y = terrain_height(c)
	dest.y = support_height(dest, dest.y + 0.3)
	player.global_position = dest
	if player.has_method("snap_camera"):
		player.snap_camera()
	Villager.bring_companions(get_tree(), dest)
	reveal(dest, REVEAL_RADIUS)


## Dévoile les lignes [y0, y1[ de la carte (le terminal dévoile tout le monde, quelques lignes par image).
## Une couleur par carré de 2 × 2 cases : quatre fois plus rapide, et invisible à l'échelle de la carte.
func reveal_rows(y0: int, y1: int) -> void:
	if map_image == null:
		return
	y0 = maxi(0, y0 - y0 % 2)
	for y in range(y0, mini(y1, world_size.y), 2):
		for x in range(0, world_size.x, 2):
			var i := y * world_size.x + x
			if _revealed[i] != 0:
				continue
			var col := map_color(Vector2i(x, y))
			for d in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
				var cx: int = x + d.x
				var cy: int = y + d.y
				if cx < world_size.x and cy < world_size.y:
					var j := cy * world_size.x + cx
					if _revealed[j] == 0:
						_revealed[j] = 1
						map_image.set_pixel(cx, cy, col)
	_map_dirty = true


## Retour au drapeau du royaume (carte, Pierre de rappel) : d'où que soit le héros, même d'un donjon, d'une grotte
## ou d'une faille (on en sort par leur propre sortie, qui mène alors au camp).
func travel_home() -> bool:
	if player == null or not has_home():
		return false
	var c := home_cell + Vector2i(0, 2)
	_ensure_chunk_of(c)
	var dest := cell_center(c)
	dest.y = support_height(dest, terrain_height(c) + 0.5)
	for g in ["dungeons", "mountain_caves", "caves", "endgame"]:
		var n := get_tree().get_first_node_in_group(g)
		if n and n.get("active"):
			n.set("_return_pos", dest)
			n.leave()
			return true
	_stream(dest, true)
	player.global_position = dest
	if player.has_method("snap_camera"):
		player.snap_camera()
	Villager.bring_companions(get_tree(), dest)
	return true


## Téléporte le héros près d'un obélisque activé (ou au village).
func travel_to(z: Dictionary) -> bool:
	if player == null or z.is_empty() or not z.obelisk_on:
		return false
	var cell: Vector2i = z.obelisk
	var dest := cell_center(cell + Vector2i(0, 2))
	_stream(dest, true)
	player.global_position = dest
	if player.has_method("snap_camera"):
		player.snap_camera()
	Villager.bring_companions(get_tree(), dest)
	reveal(dest, REVEAL_RADIUS)
	return true


const DECOR_SHADER := """
shader_type spatial;
render_mode cull_back;
uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D tex : source_color, filter_nearest_mipmap, repeat_enable;
uniform vec3 emission = vec3(0.0);
global uniform vec3 see_from;
global uniform vec3 see_to;
global uniform float see_radius;
global uniform vec4 season_leaf;
uniform float wind = 1.0;
varying vec3 wpos;
varying float tint;
float hash2(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	tint = hash2(floor(origin.xz * 3.0));
	// le vent dans les feuillages : seulement les parties vertes, et d'autant plus qu'elles sont hautes
	vec3 tc = textureLod(tex, UV, 0.0).rgb;
	float leafy = clamp((tc.g - max(tc.r, tc.b)) * 5.0, 0.0, 1.0);
	float h = max(VERTEX.y - 0.6, 0.0);
	float ph = origin.x * 0.37 + origin.z * 0.23;
	vec3 sway = vec3(sin(TIME * 1.7 + ph) + 0.4 * sin(TIME * 4.1 + ph * 2.0), 0.0, cos(TIME * 1.3 + ph)) * 0.035 * h * leafy * wind;
	VERTEX += sway;
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
vec3 lin(vec3 c) { return mix(pow((c + 0.055) / 1.055, vec3(2.4)), c / 12.92, lessThan(c, vec3(0.04045))); }
void fragment() {
	// les feuillages entre la caméra et le héros deviennent transparents
	vec3 d = see_to - see_from;
	float t = dot(wpos - see_from, d) / max(dot(d, d), 0.001);
	if (see_radius > 0.0 && t > 0.0 && t < 0.97 && wpos.y > see_to.y + 0.2) {
		float r = distance(wpos, see_from + d * t) / (see_radius * 1.25);
		float dither = fract(sin(dot(floor(FRAGCOORD.xy), vec2(12.9898, 78.233))) * 43758.5453);
		if (r < 0.7 + 0.3 * dither) { discard; }
	}
	vec3 col = albedo.rgb * texture(tex, UV).rgb;
	// saisons : les feuillages (couleurs vertes) jaunissent, rougissent ou se couvrent de neige
	float green = clamp((col.g - max(col.r, col.b)) * 6.0, 0.0, 1.0);
	if (green > 0.0 && season_leaf.a > 0.0) {
		float n = fract(sin(dot(floor(wpos.xz * 0.35), vec2(12.9898, 78.233))) * 43758.5453);
		float lum = dot(col, vec3(0.3, 0.59, 0.11));
		vec3 target = lin(season_leaf.rgb) * mix(0.7, 1.15, n) * clamp(lum * 3.2, 0.45, 1.3);
		col = mix(col, target, green * season_leaf.a);
	}
	// chaque arbre a sa nuance (un peu plus clair, plus sombre, plus jaune...)
	float leaf = clamp((col.g - max(col.r, col.b)) * 6.0, 0.0, 1.0);
	col *= 0.9 + 0.2 * tint;
	col = mix(col, col * vec3(1.08, 1.02, 0.85), leaf * step(0.6, tint) * 0.6);
	// le dessous des feuillages est plus sombre (ombre portée de la couronne)
	col *= mix(1.0, 0.82, leaf * (1.0 - smoothstep(-0.2, 0.6, (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).y)));
	ALBEDO = col;
	EMISSION = emission;
	// les feuilles laissent passer un peu de lumière
	BACKLIGHT = vec3(0.25, 0.3, 0.15) * leaf;
	ROUGHNESS = 0.95;
}
"""

## Fond de la mer : couleur et grain, seulement sous les cases d'eau (et au large, hors du monde).
const SEA_FLOOR_SHADER := """
shader_type spatial;
uniform vec4 albedo : source_color;
uniform sampler2D grain : source_color, filter_nearest_mipmap, repeat_enable;
uniform float grain_scale = 1.0;
uniform sampler2D water_mask : filter_nearest;
uniform vec2 world_size = vec2(1536.0);
void fragment() {
	vec3 wp = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 muv = wp.xz / world_size;
	if (muv.x >= 0.0 && muv.y >= 0.0 && muv.x < 1.0 && muv.y < 1.0 && texture(water_mask, muv).r < 0.5) {
		discard;
	}
	ALBEDO = albedo.rgb * texture(grain, wp.xz * grain_scale).rgb;
	ROUGHNESS = 1.0;
}
"""

## Sol : couleurs des sommets (sRGB) et grain, avec la teinte de la saison sur l'herbe et la neige l'hiver.
const TERRAIN_SHADER := """
shader_type spatial;
render_mode cull_back;
uniform sampler2D grain : source_color, filter_nearest_mipmap, repeat_enable;
uniform float water_y = -0.2;
uniform sampler2D water_mask : filter_linear;
uniform vec2 world_size = vec2(1536.0);
global uniform vec4 season_ground;
global uniform float season_snow;
varying vec3 wpos;
varying float up;
varying vec2 shade;
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	up = (MODEL_MATRIX * vec4(NORMAL, 0.0)).y;
	shade = UV2;
}
vec3 lin(vec3 c) { return mix(pow((c + 0.055) / 1.055, vec3(2.4)), c / 12.92, lessThan(c, vec3(0.04045))); }
float hash2(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
void fragment() {
	vec3 c = lin(COLOR.rgb);
	vec2 cell = floor(wpos.xz);
	if (up > 0.7 && wpos.y > water_y + 0.05) {
		float green = clamp((COLOR.g - max(COLOR.r, COLOR.b)) * 6.0, 0.0, 1.0);
		float lum = dot(c, vec3(0.3, 0.59, 0.11));
		c = mix(c, lin(season_ground.rgb) * clamp(lum * 3.0, 0.5, 1.2), green * season_ground.a);
		float n = hash2(cell);
		c = mix(c, vec3(0.86, 0.9, 0.96) * (0.92 + 0.08 * n), season_snow * COLOR.a);
		// légères variations d'une case à l'autre (l'herbe n'est jamais d'un vert uni) et taches plus larges
		float big = hash2(floor(wpos.xz / 5.0) + 17.0);
		c *= 0.93 + 0.1 * n + 0.06 * (big - 0.5);
		c = mix(c, c * vec3(1.04, 1.0, 0.9), green * big * 0.5);
		// ombrage des coins au pied des talus
		c *= clamp(shade.x, 0.55, 1.0);
	} else if (shade.y > 0.0) {
		// talus : plus sombre vers le pied, d'autant plus que le talus est haut
		float depth = clamp(shade.y / 2.5, 0.0, 1.0);
		c *= mix(1.0 - 0.38 * depth, 1.0, smoothstep(0.0, 0.85, shade.x));
	}
	// sol mouillé au bord de l'eau
	float wet = 1.0 - smoothstep(water_y + 0.02, water_y + 0.35, wpos.y);
	// seulement près d'un lac ou de la mer (pas au fond d'un trou creusé dans la terre)
	wet *= texture(water_mask, wpos.xz / world_size).r;
	c *= 1.0 - 0.25 * wet;
	ALBEDO = c * texture(grain, UV).rgb;
	ROUGHNESS = mix(1.0, 0.45, wet);
}
"""
var _decor_shader: Shader
var _decor_mats := {}


## Matériau des décors avec « fenêtre de vision » (même couleur que le matériau du modèle).
func _decor_material(src: Material) -> Material:
	var sm := src as StandardMaterial3D
	if sm == null or sm.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
		return src
	if _decor_mats.has(sm):
		return _decor_mats[sm]
	if _decor_shader == null:
		_decor_shader = Shader.new()
		_decor_shader.code = DECOR_SHADER
	var m := ShaderMaterial.new()
	m.shader = _decor_shader
	m.set_shader_parameter("albedo", sm.albedo_color)
	m.set_shader_parameter("tex", sm.albedo_texture)
	if sm.emission_enabled:
		m.set_shader_parameter("emission", Vector3(sm.emission.r, sm.emission.g, sm.emission.b) * sm.emission_energy_multiplier)
	_decor_mats[sm] = m
	return m


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
		var mesh := m.mesh
		if not Engine.is_editor_hint() and mesh is ArrayMesh:
			mesh = mesh.duplicate()
			for s in mesh.get_surface_count():
				var mat := m.get_active_material(s)
				if mat:
					(mesh as ArrayMesh).surface_set_material(s, _decor_material(mat))
		result = [mesh, xf]
	inst.free()
	_mesh_cache[scene] = result
	return result


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


# ---------------------------------------------------------------- décors démolissables du village

## Ce que rend chaque décor démoli : [[identifiant d'objet, nombre], ...].
const PROP_LOOT := {
	"hut": [["bloc_planches", 12], ["bloc_rondins", 4], ["bloc_chaume", 8]],
	"barrel": [["tonneau", 1]],
	"crate": [["bloc_planches", 3]],
	"workbench": [["etabli", 1]],
	"rack": [["ratelier", 1]],
}
var _village_props := {}
## Dégâts en cours sur les décors (récolte à la main) : case -> points de vie restants.
var decor_damage := {}
## Dégâts en cours sur les décors du village : identifiant -> points de vie restants.
var prop_damage := {}
## Dégâts en cours sur les blocs et meubles posés (cassés à la main) : clé -> points de vie restants.
var block_damage := {}
## Décors du village déjà démolis (sauvegardés).
var removed_props := {}


func _prop(id: String, n: Node3D) -> Node3D:
	if n:
		n.set_meta("prop_id", id)
		_village_props[id] = n
	return n


func village_prop(id: String) -> Node3D:
	var n: Node3D = _village_props.get(id)
	return n if n and is_instance_valid(n) and not n.is_queued_for_deletion() else null


## Boîte de collision d'un décor (repère local, sans rotation) : position = centre.
static func prop_box(n: Node3D) -> AABB:
	for c in n.get_children():
		if c is CollisionShape3D and c.shape is BoxShape3D:
			return AABB(c.position, (c.shape as BoxShape3D).size)
	return AABB(Vector3(0, 0.5, 0), Vector3.ONE)


## Décors du village dont l'emprise touche ce rectangle de cases.
func village_props_in(r: Rect2i) -> Array:
	var out := []
	var area := Rect2(Vector2(r.position), Vector2(r.size))
	for id in _village_props:
		var n := village_prop(id)
		if n == null:
			continue
		var box := prop_box(n)
		var rot := Basis(Vector3.UP, n.rotation.y)
		var lo := Vector2(INF, INF)
		var hi := Vector2(-INF, -INF)
		for sx in [-0.5, 0.5]:
			for sz in [-0.5, 0.5]:
				var q: Vector3 = n.global_position + rot * (box.position + Vector3(box.size.x * sx, 0, box.size.z * sz))
				lo = Vector2(minf(lo.x, q.x), minf(lo.y, q.z))
				hi = Vector2(maxf(hi.x, q.x), maxf(hi.y, q.z))
		if area.grow(-0.1).intersects(Rect2(lo, hi - lo)):
			out.append(n)
	return out


## Décor du village qui occupe cette case à cette hauteur (null s'il n'y en a pas).
func village_prop_at(cell: Vector2i, y: float) -> Node3D:
	for n in village_props_in(Rect2i(cell, Vector2i.ONE)):
		var box := prop_box(n)
		var bottom: float = n.global_position.y + box.position.y - box.size.y * 0.5
		var top: float = bottom + box.size.y
		if y < top - 0.05 and y + 1.0 > bottom + 0.05:
			return n
	return null


## Démolit un décor ; renvoie ce qu'il rend.
func remove_village_prop(id: String) -> Array:
	var n := village_prop(id)
	if n == null:
		return []
	var kind := id.get_slice("_", 0)
	var out := []
	for l in PROP_LOOT.get(kind, []):
		var it := Items.get_item(l[0]) as ItemData
		if it:
			out.append([it, l[1]])
	VoxelBurst.spawn(self, n.global_position + Vector3(0, 0.8, 0), Color(0.62, 0.45, 0.28), 24, 3.0, 0.1, 0.6, "up", 6.0, false)
	n.queue_free()
	_village_props.erase(id)
	removed_props[id] = true
	return out


## Pose un meuble du campement (dans la grille de construction, tourné vers le feu).
func _place_camp_furniture(id: String, offset: Vector2) -> void:
	var it := Items.get_item(id) as ItemData
	if it == null or build == null:
		return
	var origin := cell_center(spawn_cell)
	var col := cell_at(Vector3(origin.x + offset.x, 0, origin.z + offset.y))
	_ensure_chunk_of(col)
	if _decor[_idx(col)] != D_NONE:
		remove_decor(col, false)
	var to := Vector2(-offset.x, -offset.y)
	var rot := posmod(roundi(atan2(to.x, to.y) / (PI * 0.5)), 4)
	build.place_furniture(col, terrain_height(col), it, rot)


## Tourne un objet pour que sa face avant (+Z) regarde le feu.
func _face_center(n: Node3D) -> void:
	if n == null:
		return
	var to := cell_center(spawn_cell) - n.global_position
	n.rotation.y = snappedf(atan2(to.x, to.z), PI / 8.0)


func _build_village() -> void:
	_village_props.clear()
	# départ à mains nues (GameState.bare_start) : le héros arrive seul, sans feu ni habitants ;
	# tout est à fabriquer, et les habitants viendront plus tard (voyageurs à recruter)
	var bare: bool = GameState.bare_start
	if not bare:
		_spawn(campfire_scene, Vector2(0, 0))
	# pas de cabanes toutes faites : le campement n'a que des meubles posés comme ceux du joueur
	# (ils se cassent et se ramassent pareil) ; les maisons, c'est au joueur de les bâtir
	for f in [["drapeau_royaume", Vector2(0.5, -3.5)], ["etabli", Vector2(-8.5, 3.5)], ["ratelier", Vector2(9.0, 2.5)], ["tonneau", Vector2(-3.8, -5.8)],
			["tonneau", Vector2(-3.0, -6.6)], ["coffre", Vector2(3.6, -6.4)]]:
		if not bare:
			_place_camp_furniture(f[0], f[1])
	# objets posés autour du feu
	for i in (0 if bare else starting_loot.size()):
		var a := PI * 0.15 + PI * 0.7 * float(i) / maxf(1.0, starting_loot.size() - 1.0)
		var off := Vector2.from_angle(a) * (2.6 + (i % 2) * 1.0)
		var origin := cell_center(spawn_cell)
		spawn_pickup(starting_loot[i], Vector3(origin.x + off.x, origin.y, origin.z + off.y))
	if villager_scene == null or villager_races.is_empty() or bare:
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
		if v and not bare and _rng.randf() < villager_gear_chance:
			var ck := Villager.class_kit(v.get("fight_class"))
			_give_kit(v, ck if not ck.is_empty() else kits[i % kits.size()])


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
func spawn_pickup(item: ItemData, pos: Vector3, amount: int = 1, parent: Node = null) -> ItemPickup:
	if pickup_scene == null or item == null:
		return null
	var p := pickup_scene.instantiate() as ItemPickup
	p.item = item
	p.count = amount
	(parent if parent else $Village).add_child(p)
	p.global_position = Vector3(pos.x, ground_height_at(pos), pos.z)
	return p


func _ensure_noises() -> void:
	if height_noise == null:
		height_noise = FastNoiseLite.new()
		height_noise.frequency = 0.025
	if moisture_noise == null:
		moisture_noise = FastNoiseLite.new()
		moisture_noise.frequency = 0.04
	if _warp_noise == null:
		_warp_noise = FastNoiseLite.new()
		_warp_noise.frequency = 0.012
	if _ridge_noise == null:
		# crêtes des grandes chaînes de montagnes
		_ridge_noise = FastNoiseLite.new()
		_ridge_noise.frequency = 0.011
		_ridge_noise.fractal_octaves = 4
