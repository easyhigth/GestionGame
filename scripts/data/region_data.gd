class_name RegionData
extends Resource
## Un type de région du monde ouvert (prairie, forêt profonde, désert...).
## Chaque région est un fichier .tres dans data/regions/ : duplique-en un pour en créer une nouvelle.
## Le monde est découpé en zones ; chaque zone reçoit un type de région et un nom tiré de `names`.

@export var id: String = ""
@export var display_name: String = "Région"
## Noms possibles des zones de ce type (« Forêt de Sylvebrune »...).
@export var names: PackedStringArray = PackedStringArray()
@export_multiline var description: String = ""
## Niveau des monstres (min, max). Plus la zone est loin du village, plus on s'approche du max.
@export var level_range: Vector2i = Vector2i(1, 3)
## Couleur de la région sur la carte et du bandeau d'entrée.
@export var map_color: Color = Color(0.4, 0.7, 0.3)

@export_group("Choix de la région")
## Température (-1 froid à 1 chaud) et humidité (-1 sec à 1 humide) idéales de ce type.
@export_range(-1.0, 1.0, 0.05) var temperature: float = 0.0
@export_range(-1.0, 1.0, 0.05) var moisture: float = 0.0
## Distance minimale au village (0 à 1, 1 = bord du monde) pour que ce type apparaisse.
@export_range(0.0, 1.0, 0.05) var min_distance: float = 0.0

@export_group("Relief")
## Ajouté à l'altitude (-1 à 1) : > 0 pour des montagnes, < 0 pour des marais.
@export_range(-0.6, 0.6, 0.01) var height_bias: float = 0.0
## Amplifie les reliefs (1 = normal).
@export_range(0.2, 3.0, 0.05) var relief: float = 1.0

@export_group("Couleurs du sol")
@export var grass_color: Color = Color("5e9c44")
@export var grass_dark_color: Color = Color("4f8c3a")
@export var dirt_color: Color = Color("7a5a3c")
@export var sand_color: Color = Color("e0cc8a")
@export var stone_color: Color = Color("8e8c86")
@export var water_floor_color: Color = Color("c8b478")
## Couleur du liquide à la surface de l'eau (alpha 0 = eau normale). Ex. : vert pour un marais, orange pour de la lave.
@export var liquid_color: Color = Color(0, 0, 0, 0)
## Le liquide brille (lave) et brûle ceux qui s'en approchent.
@export var liquid_glow: bool = false

@export_group("Végétation")
## Arbres des forêts de la région, et arbres isolés.
@export var trees: Array[PackedScene] = []
@export_range(0.0, 1.0, 0.01) var forest_density: float = 0.3
@export_range(0.0, 1.0, 0.005) var scattered_tree_chance: float = 0.015
@export var bushes: Array[PackedScene] = []
@export_range(0.0, 1.0, 0.005) var bush_chance: float = 0.02
@export var rocks: Array[PackedScene] = []
@export_range(0.0, 1.0, 0.005) var rock_chance: float = 0.06
@export var small_plants: Array[PackedScene] = []
@export_range(0.0, 1.0, 0.005) var small_plant_chance: float = 0.1

@export_group("Monstres")
@export var enemies: Array[EnemyData] = []
## Monstres plus rares et plus forts (gardiens, chefs de meute).
@export var elite_enemies: Array[EnemyData] = []
## Nombre de camps de monstres pour 1000 cases.
@export_range(0.0, 5.0, 0.05) var camp_density: float = 0.5

@export_group("Donjon")
## Boss qui garde le donjon de cette région.
@export var boss: EnemyData
## Titre affiché à l'apparition du boss.
@export var boss_title: String = ""
## Pouvoirs du boss : "onde" (onde de choc autour de lui), "pluie" (projectiles qui tombent sur le héros),
## "invocation" (appelle des monstres de la région), "charge" (fonce sur le héros).
@export var boss_powers: PackedStringArray = PackedStringArray(["onde", "invocation"])
## Bonus permanents gagnés en absorbant l'âme du boss (clés : attack, defense, magic, regen, xp).
@export var boss_soul: Dictionary = {}
@export var boss_soul_name: String = ""
## Blocs du donjon : sol, murs et piliers.
@export var dungeon_floor: ItemData
@export var dungeon_wall: ItemData
@export var dungeon_accent: ItemData
## Couleur de l'éclairage (torches) et de l'ambiance.
@export var dungeon_light: Color = Color(1.0, 0.7, 0.4)
@export var dungeon_ambient: Color = Color(0.12, 0.1, 0.14)

@export_group("Voyageurs")
## Races des voyageurs qu'on peut recruter dans cette région.
@export var recruit_races: Array[RaceData] = []
## Campements de voyageurs pour 1000 cases.
@export_range(0.0, 1.0, 0.01) var traveler_density: float = 0.15

@export_group("Météo")
## Chances de chaque temps (clair, nuageux, pluie, orage, brouillard).
@export var weather_weights: Dictionary = {"clair": 4, "nuageux": 3, "pluie": 2, "orage": 1, "brouillard": 1}
## Ce qui tombe quand il « pleut » ici : pluie, neige, sable (tempête de sable) ou cendres.
@export_enum("pluie", "neige", "sable", "cendres") var precipitation: String = "pluie"

@export_group("Ressources")
## Matériaux qu'on trouve au sol dans cette région (au hasard).
@export var resources: Array[ItemData] = []
@export_range(0.0, 0.05, 0.001) var resource_chance: float = 0.01
