class_name PlayerStats
extends Resource
## Statistiques du joueur.
## Ouvre data/player/player_stats.tres dans l'Inspecteur pour les régler.

@export_group("Déplacement")
## Vitesse de marche, en pixels par seconde.
@export var move_speed: float = 90.0
## Vitesse à laquelle le personnage atteint sa vitesse max.
@export var acceleration: float = 900.0
## Vitesse à laquelle le personnage s'arrête.
@export var friction: float = 1100.0

@export_group("Roulade")
@export var dash_speed: float = 240.0
## Durée de la roulade, en secondes.
@export var dash_duration: float = 0.18
## Temps d'attente entre deux roulades, en secondes.
@export var dash_cooldown: float = 0.45

@export_group("Vie")
@export var max_health: int = 100
