class_name Enemy
extends Combatant
## Monstre : patrouille autour de son camp, poursuit le joueur et les habitants qui s'approchent,
## prévient avant de frapper (il clignote), puis retourne au camp s'il s'en éloigne trop.
## Laisse tomber du butin quand il est vaincu.

signal died_at(pos: Vector3)

@export var data: EnemyData

## Position du camp.
var home: Vector3
var _target: Combatant
var _wander_to := Vector3.ZERO
var _pause := randf_range(0.5, 2.0)
var _think := randf() * 0.3
var _returning := false
var _dead_time := 0.0

@onready var name_label: Label3D = $Name
@onready var bar: HealthBar3D = $HealthBar


func _ready() -> void:
	team = Team.ENEMIES
	super()
	add_to_group("enemy_units")
	home = global_position
	_wander_to = home
	if data:
		_apply_data()


func _apply_data() -> void:
	visual.set_equipment_library(data.equipment_library)
	visual.set_model(data.model)
	visual.scale = Vector3.ONE * data.model_scale
	body_radius = data.body_radius
	for it in data.equipment:
		equipment.equip(it)
	health.set_max(data.max_health, true)
	name_label.text = data.display_name
	name_label.modulate = data.color
	name_label.position.y = 2.1 * data.model_scale if not visual._quadruped else 1.5 * data.model_scale
	bar.position.y = name_label.position.y - 0.22


func base_attack() -> int:
	return data.attack if data else 8


func base_defense() -> int:
	return data.defense if data else 0


func base_magic() -> int:
	return data.magic if data else 0


func attack_power() -> int:
	return base_attack() + equipment.total_attack()


func attack_reach() -> float:
	return data.attack_range if data else 1.5


func attack_duration() -> float:
	return data.attack_duration if data else 0.7


func knockback_strength() -> float:
	return data.knockback if data else 4.0


func start_attack() -> bool:
	if super():
		# avertissement : le monstre clignote de sa couleur juste avant de frapper
		visual.flash(Color(data.color, 0.55) if data else Color(1, 0.4, 0.2, 0.55), attack_duration() * 0.4)
		_attack_cooldown = attack_duration() + (data.attack_cooldown if data else 1.0)
		return true
	return false


func _physics_process(delta: float) -> void:
	_combat_step(delta)
	if not is_alive():
		_dead_time += delta
		velocity = Vector3.ZERO
		visual.animate(delta, Vector3.ZERO, facing)
		if _dead_time > 1.2:
			visual.scale = visual.scale.move_toward(Vector3.ZERO, delta * 2.5)
			if visual.scale.x <= 0.02:
				queue_free()
		return
	# loin du joueur et au calme : on ne calcule presque rien
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var player_dist := player.global_position.distance_to(global_position) if player else 0.0
	name_label.visible = player_dist < 12.0 or _target != null
	if player and _target == null and player_dist > 45.0:
		return
	_think -= delta
	if _think <= 0.0:
		_think = 0.3
		_choose_target()
	var speed := data.move_speed if data else 3.5
	if _target:
		var to := _target.global_position - global_position
		to.y = 0.0
		var dist := to.length()
		if dist > 0.01 and not is_attacking():
			facing = to / dist
		if dist > attack_reach() + _target.body_radius * 0.5:
			velocity = facing * speed if not is_attacking() else Vector3.ZERO
		else:
			velocity = Vector3.ZERO
			start_attack()
	else:
		var to := _wander_to - global_position
		to.y = 0.0
		var run := speed * (1.0 if _returning else 0.35)
		if to.length() > 0.3:
			facing = to.normalized()
			velocity = facing * run
		else:
			velocity = Vector3.ZERO
			_returning = false
			_pause -= delta
			if _pause <= 0.0:
				_pause = randf_range(1.5, 4.0)
				var off := Vector2.from_angle(randf() * TAU) * randf_range(0.5, 4.0)
				_wander_to = home + Vector3(off.x, 0, off.y)
	var before := global_position
	_move_on_ground(delta)
	if velocity.length() > 0.1 and before.distance_to(global_position) < 0.002 and _target == null:
		_wander_to = home
	visual.animate(delta, velocity, facing)


func _choose_target() -> void:
	var range_home := data.leash_range if data else 18.0
	if _target:
		var lost := not is_instance_valid(_target) or not _target.can_be_targeted() \
				or global_position.distance_to(home) > range_home \
				or _target.global_position.distance_to(global_position) > (data.aggro_range if data else 9.0) * 1.8
		if lost:
			_target = null
			_returning = true
			_wander_to = home
			health.heal(health.max_health)
		return
	if _returning:
		return
	var t := nearest_hostile(data.aggro_range if data else 9.0)
	if t and t.global_position.distance_to(home) < range_home:
		_target = t


func _on_hurt(_amount: int, source: Node) -> void:
	# riposte contre celui qui l'a frappé (même un sort lancé de loin)
	var src := source
	if source is MagicBolt:
		src = (source as MagicBolt).shooter
	if src is Combatant and (src as Combatant).is_alive():
		_target = src
		_returning = false


func _on_died() -> void:
	super()
	collision_layer = 0
	name_label.visible = false
	bar.visible = false
	_drop_loot()
	died_at.emit(global_position)


func _drop_loot() -> void:
	if data == null:
		return
	var world := get_tree().get_first_node_in_group("world") as WorldGenerator
	if world == null:
		return
	var n := 0
	for i in data.loot.size():
		var chance := data.loot_chances[i] if i < data.loot_chances.size() else 0.5
		if randf() < chance:
			var a := TAU * n / 5.0 + randf() * 0.5
			world.spawn_pickup(data.loot[i], global_position + Vector3(cos(a), 0, sin(a)) * 0.9)
			n += 1
