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
## Ses attaques (animations de MoveLibrary : enemy_chop, enemy_sweep, bite, charge_ram...). Une au hasard.
@export var attack_moves: PackedStringArray = PackedStringArray(["enemy_chop"])
## Vitesse de ses attaques (1 = normale, plus bas = plus lent et plus facile à esquiver).
@export var attack_speed: float = 1.0
## Équilibre : quand il tombe à 0, le monstre est étourdi. Sous 20, chaque coup l'interrompt.
@export var poise: float = 20.0
## Pause entre deux coups.
@export var attack_cooldown: float = 1.0
@export var knockback: float = 4.0
## Rayon du corps.
@export var body_radius: float = 0.4

## Expérience donnée quand il est vaincu (0 = calculée d'après sa vie et son attaque).
@export var xp_reward: int = 0

@export_group("Butin")
## Objets qu'il peut laisser tomber ; loot_chances[i] = chance (0 à 1) de lâcher loot[i].
@export var loot: Array[ItemData] = []
@export var loot_chances: PackedFloat32Array = PackedFloat32Array()

@export_group("Tir à distance")
## Attaque à distance (animation de MoveLibrary : enemy_shoot, enemy_spell, spit) ; vide = corps à corps seulement.
@export var ranged_move: String = ""
## Il tire quand sa cible est à plus de 3,5 m et à moins de cette distance (au contact, il frappe).
@export var ranged_range: float = 0.0
## Projectile : « bolt » (orbe lumineux de sa couleur) ou « arrow » (flèche).
@export var projectile: String = "bolt"
@export var projectile_color: Color = Color(1.0, 0.6, 0.3)
## Dégâts d'un tir (× attaque).
@export var ranged_damage: float = 0.8
## Nombre de projectiles par tir (en éventail).
@export var ranged_spread: int = 1

@export_group("Boss")
## Attaque spéciale propre à ce boss (voir Boss._special) : « ronces », « eboulement », « blizzard », « plumes »,
## « toile », « ruee », « dard », « eruption », « acide ». Vide = pas d'attaque spéciale.
@export var special_attack: String = ""
## Nom annoncé à l'écran quand il la lance.
@export var special_name: String = ""
