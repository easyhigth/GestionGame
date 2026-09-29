class_name Villager
extends CharacterBody3D
## Habitant du village : se promène autour de sa maison.
## La race se choisit dans l'Inspecteur (ou par le générateur de monde).

@export var race: RaceData
## Vitesse de marche, en mètres par seconde.
@export var walk_speed: float = 1.4
## Distance max (en mètres) autour du point de départ.
@export var wander_radius: float = 4.0
@export var min_pause: float = 1.0
@export var max_pause: float = 3.5

@onready var visual: VoxelCharacter = $Visual

var home: Vector3
var facing := Vector3.BACK
var _target := Vector3.ZERO
var _pause := 0.0
var _world: WorldGenerator


func _ready() -> void:
	home = global_position
	_target = home
	_pause = randf_range(0.0, max_pause)
	facing = Vector3.FORWARD.rotated(Vector3.UP, randf() * TAU)
	set_race(race)


func set_race(new_race: RaceData) -> void:
	race = new_race
	var vis := get_node_or_null("Visual") as VoxelCharacter
	if race == null or vis == null:
		return
	if not race.villager_models.is_empty():
		vis.set_model(race.villager_models.pick_random())
	elif race.model:
		vis.set_model(race.model)


func _physics_process(delta: float) -> void:
	if _world == null:
		_world = get_tree().get_first_node_in_group("world") as WorldGenerator
	if _pause > 0.0:
		_pause -= delta
		velocity = Vector3.ZERO
		if _pause <= 0.0:
			var off := Vector2.from_angle(randf() * TAU) * randf_range(0.7, wander_radius)
			_target = home + Vector3(off.x, 0, off.y)
	else:
		var to_target := _target - global_position
		to_target.y = 0.0
		if to_target.length() < 0.15:
			_pause = randf_range(min_pause, max_pause)
			velocity = Vector3.ZERO
		else:
			facing = to_target.normalized()
			velocity = facing * walk_speed * (race.speed_multiplier if race else 1.0)
	var before := global_position
	move_and_slide()
	if _world:
		global_position = _world.constrain_move(before, global_position)
		global_position.y = lerpf(global_position.y, _world.ground_height_at(global_position), clampf(18.0 * delta, 0.0, 1.0))
	# bloqué contre un obstacle : on s'arrête et on repart ailleurs
	if _pause <= 0.0 and velocity.length() > 0.0 and Vector2(global_position.x - before.x, global_position.z - before.z).length() < 0.005:
		_pause = randf_range(min_pause, max_pause)
	visual.animate(delta, velocity, facing)
