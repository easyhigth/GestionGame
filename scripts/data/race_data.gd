class_name RaceData
extends Resource
## Une race jouable / recrutable.
## Chaque race est un fichier .tres dans data/races/ : duplique-en un pour en créer une nouvelle.

@export var display_name: String = "Race"
## Nom du modèle dans les fichiers .glb (ex. « human », « kijin »).
@export var model_id: String = ""
@export_multiline var description: String = ""
## Modèle 3D voxel (.glb) du joueur quand il joue cette race (version nue, l'équipement s'ajoute par-dessus).
## Les modèles sont dans assets/characters/models/base/ (race_base.glb, _v2 et _v3 = autres palettes).
@export var model: PackedScene
## Modèles possibles pour les habitants de cette race (un est tiré au hasard).
## Laisser vide pour utiliser « model ».
@export var villager_models: Array[PackedScene] = []
## Équipements taillés pour cette race (fichier assets/equipment/<race>_equipment.glb).
@export var equipment: PackedScene

@export_group("Caractéristiques de base")
@export var max_health: int = 100
@export var strength: int = 10
@export var agility: int = 10
@export var magic: int = 10
## Multiplicateur de vitesse de déplacement.
@export_range(0.5, 2.0, 0.05) var speed_multiplier: float = 1.0
