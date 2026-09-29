class_name PlayerStats
extends Resource
## Statistiques du joueur.
## Ouvre data/player/player_stats.tres dans l'Inspecteur pour les régler.

@export_group("Déplacement")
## Vitesse de marche, en mètres par seconde.
@export var move_speed: float = 4.5
## Vitesse à laquelle le personnage atteint sa vitesse max.
@export var acceleration: float = 40.0
## Vitesse à laquelle le personnage s'arrête.
@export var friction: float = 48.0

@export_group("Roulade")
@export var dash_speed: float = 10.0
## Durée de la roulade, en secondes.
@export var dash_duration: float = 0.3
## Temps d'attente entre deux roulades, en secondes.
@export var dash_cooldown: float = 0.45

@export_group("Vie")
@export var max_health: int = 100
