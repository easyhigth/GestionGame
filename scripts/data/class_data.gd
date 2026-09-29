class_name ClassData
extends Resource
## Une classe de héros (guerrier, mage...). Chaque classe est un fichier .tres dans data/classes/.
## Elle donne l'équipement de départ, des bonus et la progression à chaque niveau.

@export var display_name: String = "Classe"
@export_multiline var description: String = ""
## Couleur de la classe dans les menus.
@export var color: Color = Color.WHITE
## Équipement porté au départ.
@export var starting_equipment: Array[ItemData] = []

@export_group("Bonus de départ")
@export var bonus_health: int = 0
@export var bonus_attack: int = 0
@export var bonus_defense: int = 0
@export var bonus_magic: int = 0

@export_group("Gain à chaque niveau")
@export var health_per_level: int = 10
@export var attack_per_level: float = 1.0
@export var defense_per_level: float = 0.3
@export var magic_per_level: float = 1.0
