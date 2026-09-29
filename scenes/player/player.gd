class_name Player
extends Combatant
## Personnage joueur : déplacement 8 directions, roulade (invulnérable), coups d'arme, sorts.
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
## Temps avant de se relever au village après avoir été vaincu (secondes).
@export var respawn_delay: float = 4.0

@onready var camera: Camera3D = $Camera

## Le sac du joueur.
var inventory := Inventory.new()
## Vrai quand une fenêtre est ouverte (le joueur ne bouge plus).
var ui_open := false

var _dash_time := 0.0
var _dash_cooldown_left := 0.0
var _dash_dir := Vector3.ZERO
var _respawn_left := 0.0
var _shake := 0.0


func _ready() -> void:
	super()
	add_to_group("player")
	if stats == null:
		stats = PlayerStats.new()
	camera.top_level = true
	apply_race(race)
	health.set_max(race.max_health if race else stats.max_health, true)
	snap_camera()


func apply_race(new_race: RaceData) -> void:
	race = new_race
	if race:
		visual.set_equipment_library(race.equipment)
		if race.model:
			visual.set_model(race.model)
		if is_node_ready():
			health.set_max(race.max_health)


func base_attack() -> int:
	return race.strength if race else 10


func base_magic() -> int:
	return race.magic if race else 10


## Secoue la caméra (coup reçu, coup porté).
func shake(strength: float) -> void:
	_shake = maxf(_shake, strength)


## Place la caméra directement sur le joueur (sans glissement).
func snap_camera() -> void:
	camera.global_position = global_position + camera_offset
	camera.look_at(global_position + Vector3(0, 0.8, 0))


func _physics_process(delta: float) -> void:
	_combat_step(delta)
	_dash_cooldown_left = maxf(_dash_cooldown_left - delta, 0.0)
	if not is_alive():
		_respawn_left -= delta
		velocity = Vector3.ZERO
		_move_on_ground(delta)
		visual.animate(delta, Vector3.ZERO, facing)
		_update_camera(delta)
		if _respawn_left <= 0.0:
			_respawn()
		return
	var can_act := not ui_open
	var input2 := Vector2.ZERO if not can_act else Input.get_vector("move_left", "move_right", "move_up", "move_down")
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

		if can_act and Input.is_action_just_pressed("dash") and _dash_cooldown_left <= 0.0:
			_start_dash(input if input != Vector3.ZERO else facing)
		if can_act and Input.is_action_pressed("attack") and can_attack():
			if input != Vector3.ZERO:
				facing = input
			_aim_assist()
			start_attack()

	# on avance moins vite pendant un coup
	if is_attacking() and not is_dashing():
		velocity *= 0.35
	_move_on_ground(delta)
	visual.animate(delta, velocity, facing)
	_update_camera(delta)


func _update_camera(delta: float) -> void:
	var target := global_position + camera_offset
	camera.global_position = camera.global_position.lerp(target, clampf(camera_smoothing * delta, 0.0, 1.0))
	camera.look_at(camera.global_position - camera_offset + Vector3(0, 0.8, 0))
	if _shake > 0.0:
		camera.global_position += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * _shake * 0.12
		_shake = maxf(_shake - delta * 4.0, 0.0)


## Se tourne vers l'ennemi le plus proche s'il est presque en face (aide à viser).
func _aim_assist() -> void:
	var reach := minf(attack_reach(), 8.0) + 1.0
	var enemy := nearest_hostile(reach)
	if enemy == null:
		return
	var to := enemy.global_position - global_position
	to.y = 0.0
	if to.length() > 0.01 and Vector2(facing.x, facing.z).angle_to(Vector2(to.x, to.z)) < deg_to_rad(70.0) \
			and Vector2(facing.x, facing.z).angle_to(Vector2(to.x, to.z)) > -deg_to_rad(70.0):
		facing = to.normalized()
		visual.rotation.y = atan2(facing.x, facing.z)


func _on_attack_landed(hits: int) -> void:
	if hits > 0:
		shake(0.6)


func _on_hurt(amount: int, _source: Node) -> void:
	shake(0.8 + amount * 0.04)


func _on_died() -> void:
	super()
	_respawn_left = respawn_delay
	_dash_time = 0.0
	notify.emit("Vous êtes tombé au combat…")


## Se relève au village, avec toute sa vie.
func _respawn() -> void:
	if _world:
		global_position = _world.cell_center(_world.spawn_cell) + Vector3(0, 0, 3)
	health.revive(1.0)
	visual.set_downed(false)
	_knockback = Vector3.ZERO
	_invulnerable_left = 2.0
	snap_camera()
	notify.emit("Vous vous réveillez au village.")


func is_dashing() -> bool:
	return _dash_time > 0.0


## Invulnérable pendant la roulade : c'est l'esquive.
func is_invulnerable() -> bool:
	return is_dashing() or super()


func _start_dash(direction: Vector3) -> void:
	_dash_dir = direction.normalized()
	facing = _dash_dir
	_dash_time = stats.dash_duration
	_dash_cooldown_left = stats.dash_cooldown
	visual.play_roll(stats.dash_duration)
	dashed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if ui_open or not is_alive():
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
		"health": health.current,
		"max_health": health.max_health,
		"attack": attack_power(),
		"defense": defense_power(),
		"magic": magic_power(),
		"speed": r.speed_multiplier * equipment.speed_multiplier(),
	}


func display_title() -> String:
	return "Vous (%s)" % (race.display_name if race else "?")
