class_name RaceData
extends Resource
## Une race jouable / recrutable.
## Chaque race est un fichier .tres dans data/races/ : duplique-en un pour en créer une nouvelle.

@export var display_name: String = "Race"
@export_multiline var description: String = ""
## Animations (idle_down, walk_down, idle_up, walk_up, idle_side, walk_side).
## La vue « side » regarde vers la gauche ; elle est retournée automatiquement vers la droite.
@export var sprite_frames: SpriteFrames

@export_group("Caractéristiques de base")
@export var max_health: int = 100
@export var strength: int = 10
@export var agility: int = 10
@export var magic: int = 10
## Multiplicateur de vitesse de déplacement.
@export_range(0.5, 2.0, 0.05) var speed_multiplier: float = 1.0
