class_name Player
extends CharacterBody3D
## Personnage joueur : déplacement 8 directions, roulade, animations.
## Change la race dans l'Inspecteur (propriété « race ») pour jouer n'importe quelle race.

signal dashed
## Un message à afficher (objet ramassé, équipé, fabriqué...).
signal notify(text: String)
## Le joueur veut ouvrir l'inventaire d'un personnage (lui-même ou un habitant proche).
signal open_inventory(target: Node)

@export var stats: PlayerStats
@export var race: RaceData
## Position de la caméra par rapport au joueur (en mètres).
@export var camera_offset: Vector3 = Vector3(0, 10, 10)
@export var camera_smoothing: float = 8.0

## Distance max pour parler à un habitant ou utiliser l'établi.
@export var interact_distance: float = 2.4
## Équipe automatiquement un objet ramassé si l'emplacement est vide.
@export var auto_equip: bool = true

@onready var visual: VoxelCharacter = $Visual
@onready var camera: Camera3D = $Camera
@onready var equipment: CharacterEquipment = $Equipment

## Le sac du joueur.
var inventory := Inventory.new()
## Vrai quand une fenêtre est ouverte (le joueur ne bouge plus).
var ui_open := false

## Dernière direction regardée (sert aux animations et à la roulade).
var facing: Vector3 = Vector3.BACK
var health: int

var _dash_time := 0.0
var _dash_cooldown_left := 0.0
var _dash_dir := Vector3.ZERO
var _world: WorldGenerator


func _ready() -> void:
	add_to_group("player")
	if stats == null:
		stats = PlayerStats.new()
	health = stats.max_health
	camera.top_level = true
	apply_race(race)
	snap_camera()


func apply_race(new_race: RaceData) -> void:
	race = new_race
	if race:
		visual.set_equipment_library(race.equipment)
		if race.model:
			visual.set_model(race.model)


## Place la caméra directement sur le joueur (sans glissement).
func snap_camera() -> void:
	camera.global_position = global_position + camera_offset
	camera.look_at(global_position + Vector3(0, 0.8, 0))


func _physics_process(delta: float) -> void:
	if _world == null:
		_world = get_tree().get_first_node_in_group("world") as WorldGenerator
	_dash_cooldown_left = maxf(_dash_cooldown_left - delta, 0.0)
	var input2 := Vector2.ZERO if ui_open else Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var input := Vector3(input2.x, 0, input2.y)
	var speed := stats.move_speed * (race.speed_multiplier if race else 1.0) * equipment.speed_multiplier()

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

		if not ui_open and Input.is_action_just_pressed("dash") and _dash_cooldown_left <= 0.0:
			_start_dash(input if input != Vector3.ZERO else facing)
		if not ui_open and Input.is_action_just_pressed("attack") and not visual.is_attacking():
			visual.play_attack()

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


func _unhandled_input(event: InputEvent) -> void:
	if ui_open:
		return
	if event.is_action_pressed("interact"):
		var v := nearest_villager()
		open_inventory.emit(v if v else self)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("inventory"):
		open_inventory.emit(self)
		get_viewport().set_input_as_handled()


## L'habitant le plus proche à portée (ou null).
func nearest_villager() -> Node3D:
	var best: Node3D = null
	var best_d := interact_distance
	for v in get_tree().get_nodes_in_group("villagers"):
		var d := (v as Node3D).global_position.distance_to(global_position)
		if d < best_d:
			best_d = d
			best = v
	return best


func is_near_workbench() -> bool:
	for w in get_tree().get_nodes_in_group("workbench"):
		if (w as Node3D).global_position.distance_to(global_position) < interact_distance + 1.2:
			return true
	return false


## Appelé par un objet au sol quand le joueur marche dessus.
func try_pickup(pickup: ItemPickup) -> void:
	if pickup.item == null or pickup.is_taken():
		return
	var item := pickup.item
	pickup.take()
	if auto_equip and item.is_equipment() and equipment.get_item(item.slot) == null \
			and not (item.slot == ItemData.Slot.OFF_HAND and equipment.get_item(ItemData.Slot.MAIN_HAND) \
			and equipment.get_item(ItemData.Slot.MAIN_HAND).two_handed):
		for old in equipment.equip(item):
			inventory.add(old)
		notify.emit("%s équipé(e) !" % item.display_name)
	else:
		inventory.add(item, pickup.count)
		notify.emit("+%d %s" % [pickup.count, item.display_name])


## Attaque, défense et magie totales (race + équipement).
func total_stats() -> Dictionary:
	var r := race if race else RaceData.new()
	return {
		"health": r.max_health,
		"attack": r.strength + equipment.total_attack(),
		"defense": equipment.total_defense(),
		"magic": r.magic + equipment.total_magic(),
		"speed": r.speed_multiplier * equipment.speed_multiplier(),
	}


func display_title() -> String:
	return "Vous (%s)" % (race.display_name if race else "?")
