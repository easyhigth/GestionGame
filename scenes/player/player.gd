class_name Player
extends CharacterBody3D
## Personnage joueur : déplacement 8 directions, roulade, animations.
## Change la race dans l'Inspecteur (propriété « race ») pour jouer n'importe quelle race.

signal dashed

@export var stats: PlayerStats
@export var race: RaceData
## Position de la caméra par rapport au joueur (en mètres).
@export var camera_offset: Vector3 = Vector3(0, 10, 10)
@export var camera_smoothing: float = 8.0

@onready var visual: VoxelCharacter = $Visual
@onready var camera: Camera3D = $Camera

## Dernière direction regardée (sert aux animations et à la roulade).
var facing: Vector3 = Vector3.BACK
var health: int

var _dash_time := 0.0
var _dash_cooldown_left := 0.0
var _dash_dir := Vector3.ZERO
var _world: WorldGenerator


func _ready() -> void:
	if stats == null:
		stats = PlayerStats.new()
	health = stats.max_health
	camera.top_level = true
	apply_race(race)
	snap_camera()


func apply_race(new_race: RaceData) -> void:
	race = new_race
	if race and race.model:
		visual.set_model(race.model)


## Place la caméra directement sur le joueur (sans glissement).
func snap_camera() -> void:
	camera.global_position = global_position + camera_offset
	camera.look_at(global_position + Vector3(0, 0.8, 0))


func _physics_process(delta: float) -> void:
	if _world == null:
		_world = get_tree().get_first_node_in_group("world") as WorldGenerator
	_dash_cooldown_left = maxf(_dash_cooldown_left - delta, 0.0)
	var input2 := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var input := Vector3(input2.x, 0, input2.y)
	var speed := stats.move_speed * (race.speed_multiplier if race else 1.0)

	if is_dashing():
		_dash_time -= delta
		velocity = _dash_dir * stats.dash_speed
	else:
		var horizontal := Vector3(velocity.x, 0, velocity.z)
		if input != Vector3.ZERO:
			facing = input
			horizontal = horizontal.move_toward(input * speed, stats.acceleration * delta)
		else:
			horizontal = horizontal.move_toward(Vector3.ZERO, stats.friction * delta)
		velocity = horizontal

		if Input.is_action_just_pressed("dash") and _dash_cooldown_left <= 0.0:
			_start_dash(input if input != Vector3.ZERO else facing)

	velocity.y = 0.0
	var before := global_position
	move_and_slide()
	if _world:
		global_position = _world.constrain_move(before, global_position)
		var ground := _world.ground_height_at(global_position)
		global_position.y = lerpf(global_position.y, ground, clampf(18.0 * delta, 0.0, 1.0))
	visual.animate(delta, velocity, facing)

	var target := global_position + camera_offset
	camera.global_position = camera.global_position.lerp(target, clampf(camera_smoothing * delta, 0.0, 1.0))
	camera.look_at(camera.global_position - camera_offset + Vector3(0, 0.8, 0))


func is_dashing() -> bool:
	return _dash_time > 0.0


## Invulnérable pendant la roulade (utilisé par le combat plus tard).
func is_invulnerable() -> bool:
	return is_dashing()


func _start_dash(direction: Vector3) -> void:
	_dash_dir = direction.normalized()
	facing = _dash_dir
	_dash_time = stats.dash_duration
	_dash_cooldown_left = stats.dash_cooldown
	visual.play_roll(stats.dash_duration)
	dashed.emit()
