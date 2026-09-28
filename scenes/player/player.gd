class_name Player
extends CharacterBody2D
## Personnage joueur : déplacement 8 directions, roulade, animations.
## Change la race dans l'Inspecteur (propriété « race ») pour jouer n'importe quelle race.

signal dashed

@export var stats: PlayerStats
@export var race: RaceData

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var camera: Camera2D = $Camera

## Dernière direction regardée (sert aux animations et à la roulade).
var facing: Vector2 = Vector2.DOWN
var health: int

var _dash_time := 0.0
var _dash_cooldown_left := 0.0
var _dash_dir := Vector2.ZERO


func _ready() -> void:
	if stats == null:
		stats = PlayerStats.new()
	health = stats.max_health
	apply_race(race)


func apply_race(new_race: RaceData) -> void:
	race = new_race
	if race and race.sprite_frames:
		sprite.sprite_frames = race.sprite_frames
		sprite.play("idle_down")


func _physics_process(delta: float) -> void:
	_dash_cooldown_left = maxf(_dash_cooldown_left - delta, 0.0)
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var speed := stats.move_speed * (race.speed_multiplier if race else 1.0)

	if is_dashing():
		_dash_time -= delta
		velocity = _dash_dir * stats.dash_speed
		if not is_dashing():
			sprite.modulate = Color.WHITE
	else:
		if input != Vector2.ZERO:
			facing = input
			velocity = velocity.move_toward(input * speed, stats.acceleration * delta)
		else:
			velocity = velocity.move_toward(Vector2.ZERO, stats.friction * delta)

		if Input.is_action_just_pressed("dash") and _dash_cooldown_left <= 0.0:
			_start_dash(input if input != Vector2.ZERO else facing)

	move_and_slide()
	CharacterAnimator.update(sprite, facing, velocity)
	sprite.speed_scale = 2.0 if is_dashing() else 1.0


func is_dashing() -> bool:
	return _dash_time > 0.0


## Invulnérable pendant la roulade (utilisé par le combat plus tard).
func is_invulnerable() -> bool:
	return is_dashing()


func _start_dash(direction: Vector2) -> void:
	_dash_dir = direction.normalized()
	_dash_time = stats.dash_duration
	_dash_cooldown_left = stats.dash_cooldown
	sprite.modulate = Color(1.4, 1.4, 1.6)
	dashed.emit()
