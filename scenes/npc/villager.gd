class_name Villager
extends CharacterBody2D
## Habitant du village : se promène autour de sa maison.
## La race se choisit dans l'Inspecteur (ou par le générateur de monde).

@export var race: RaceData
@export var walk_speed: float = 45.0
## Distance max (en pixels) autour du point de départ.
@export var wander_radius: float = 120.0
@export var min_pause: float = 1.0
@export var max_pause: float = 3.5

@onready var sprite: AnimatedSprite2D = $Sprite

var home: Vector2
var facing := Vector2.DOWN
var _target := Vector2.ZERO
var _pause := 0.0


func _ready() -> void:
	home = global_position
	_target = home
	_pause = randf_range(0.0, max_pause)
	set_race(race)


func set_race(new_race: RaceData) -> void:
	race = new_race
	var spr := get_node_or_null("Sprite") as AnimatedSprite2D
	if race and race.sprite_frames and spr:
		spr.sprite_frames = race.sprite_frames
		spr.play("idle_down")


func _physics_process(delta: float) -> void:
	if _pause > 0.0:
		_pause -= delta
		velocity = Vector2.ZERO
		if _pause <= 0.0:
			_target = home + Vector2.from_angle(randf() * TAU) * randf_range(20.0, wander_radius)
	else:
		var to_target := _target - global_position
		if to_target.length() < 4.0:
			_pause = randf_range(min_pause, max_pause)
			velocity = Vector2.ZERO
		else:
			facing = to_target.normalized()
			velocity = facing * walk_speed * (race.speed_multiplier if race else 1.0)
	var before := global_position
	move_and_slide()
	# bloqué contre un obstacle : on s'arrête et on repart ailleurs
	if _pause <= 0.0 and velocity.length() > 0.0 and global_position.distance_to(before) < 0.2:
		_pause = randf_range(min_pause, max_pause)
	CharacterAnimator.update(sprite, facing, velocity)
