class_name EnemyData
extends Resource
## Un type de monstre. Chaque monstre est un fichier .tres dans data/enemies/ :
## duplique-en un pour en créer un nouveau.

@export var display_name: String = "Monstre"
## Modèle 3D voxel (.glb) : un personnage nu (assets/characters/models/base/)
## ou une créature (assets/characters/creatures/).
@export var model: PackedScene
## Équipements de la race du modèle (assets/equipment/<race>_equipment.glb), si le monstre en porte.
@export var equipment_library: PackedScene
## Armes et armures portées (elles comptent dans l'attaque et la défense).
@export var equipment: Array[ItemData] = []
## Taille du modèle (1 = normale).
@export var model_scale: float = 1.0
## Couleur du nom et de l'avertissement avant une attaque.
@export var color: Color = Color(1.0, 0.45, 0.3)

@export_group("Caractéristiques")
@export var max_health: int = 40
@export var attack: int = 8
@export var defense: int = 0
@export var magic: int = 0
## Vitesse de course (mètres par seconde).
@export var move_speed: float = 3.6
## Distance à laquelle il repère une proie.
@export var aggro_range: float = 9.0
## Il abandonne la poursuite au-delà de cette distance de son camp.
@export var leash_range: float = 18.0
## Portée de son coup.
@export var attack_range: float = 1.5
## Durée du coup : le monstre prévient (clignote) puis frappe au milieu.
@export var attack_duration: float = 0.7
## Pause entre deux coups.
@export var attack_cooldown: float = 1.0
@export var knockback: float = 4.0
## Rayon du corps.
@export var body_radius: float = 0.4

@export_group("Butin")
## Objets qu'il peut laisser tomber ; loot_chances[i] = chance (0 à 1) de lâcher loot[i].
@export var loot: Array[ItemData] = []
@export var loot_chances: PackedFloat32Array = PackedFloat32Array()
