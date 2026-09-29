class_name Enemy
extends Combatant
## Monstre : patrouille autour de son camp et poursuit ceux qui s'approchent.
## En combat, il tourne autour de sa cible et n'attaque que s'il a un « jeton » (2 attaquants max
## par cible) : chaque attaque est annoncée (pose de préparation, flash de sa couleur, « ! »),
## ce qui laisse le temps d'esquiver ou de parer. Laisse tomber du butin quand il est vaincu.

signal died_at(pos: Vector3)

@export var data: EnemyData
## Niveau (affiché) et multiplicateur de puissance, fixés par le camp selon la région.
@export var level: int = 1
@export var power: float = 1.0

## Position du camp.
var home: Vector3
var _target: Combatant
var _wander_to := Vector3.ZERO
var _pause := randf_range(0.5, 2.0)
var _think := randf() * 0.3
var _returning := false
var _dead_time := 0.0
var _orbit_dir := 1.0 if randf() < 0.5 else -1.0
var _orbit_timer := 0.0
var _has_token := false
var _fear_left := 0.0

@onready var name_label: Label3D = $Name
@onready var bar: HealthBar3D = $HealthBar


func _ready() -> void:
	team = Team.ENEMIES
	# pas d'invulnérabilité après un coup : les combos du joueur s'enchaînent
	hit_invulnerability = 0.0
	if data:
		poise_max = data.poise
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
	visual.trail_color = Color(data.color, 1.0).lightened(0.3)
	body_radius = data.body_radius
	for it in data.equipment:
		equipment.equip(it)
	health.set_max(roundi(data.max_health * power), true)
	name_label.text = "%s · Nv %d" % [data.display_name, level]
	name_label.modulate = data.color
	name_label.position.y = 2.1 * data.model_scale if not visual.is_quadruped() else 1.5 * data.model_scale
	bar.position.y = name_label.position.y - 0.22


func base_attack() -> int:
	return roundi((data.attack if data else 8) * power)


func base_defense() -> int:
	return roundi((data.defense if data else 0) * power)


func base_magic() -> int:
	return data.magic if data else 0


func attack_power() -> int:
	return base_attack() + equipment.total_attack()


func attack_reach() -> float:
	return data.attack_range if data else 1.5


func knockback_strength() -> float:
	return data.knockback if data else 4.0


func _start_attack() -> void:
	var moves := data.attack_moves if data and not data.attack_moves.is_empty() else PackedStringArray(["enemy_chop"])
	var m: String = moves[randi() % moves.size()]
	if not perform(m, data.attack_speed if data else 1.0):
		return
	# avertissement : il prend la pose de préparation en clignotant de sa couleur
	var windup := float(MoveLibrary.get_move(m).get("windup", 0.4)) / move_speed
	visual.flash(Color(data.color if data else Color(1, 0.4, 0.2), 0.5), windup)
	Combat.popup(self, global_position + Vector3(0, name_label.position.y + 0.3, 0), "!", Color("ff4a3a"), true)


func _on_move_ended(_name: String, _interrupted: bool) -> void:
	_attack_cooldown = (data.attack_cooldown if data else 1.0) * randf_range(0.8, 1.3)
	_release_token()


func _release_token() -> void:
	if _has_token:
		Combat.release_token(_target, self)
		_has_token = false


func _physics_process(delta: float) -> void:
	_combat_step(delta)
	if not is_alive():
		_dead_time += delta
		velocity = Vector3.ZERO
		visual.animate(delta, Vector3.ZERO, facing)
		if _dead_time > 1.0:
			visual.scale = visual.scale.move_toward(Vector3.ZERO, delta * 2.5)
			if visual.scale.x <= 0.02:
				queue_free()
		return
	# loin du joueur et au calme : on ne calcule presque rien
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var player_dist := player.global_position.distance_to(global_position) if player else 0.0
	name_label.visible = player_dist < 12.0 or _target != null
	if player and _target == null and player_dist > 45.0 and not has_meta("raider"):
		return
	_think -= delta
	if _think <= 0.0:
		_think = 0.3
		_choose_target()
	var speed := (data.move_speed if data else 3.5) * speed_factor()
	velocity = Vector3.ZERO
	if _fear_left > 0.0:
		_fear_left -= delta
		var away := global_position - (player.global_position if player else home)
		away.y = 0.0
		facing = away.normalized() if away.length() > 0.01 else facing
		velocity = facing * speed * 1.1
		cancel_move()
		_move_on_ground(delta)
		visual.animate(delta, velocity, facing)
		return
	if not can_act() or in_move():
		pass
	elif _target:
		_fight(delta, speed)
	else:
		_wander(delta, speed)
	var before := global_position
	_move_on_ground(delta)
	if velocity.length() > 0.1 and before.distance_to(global_position) < 0.002 and _target == null:
		_wander_to = home
	visual.animate(delta, velocity, facing)


func _fight(delta: float, speed: float) -> void:
	var to := _target.global_position - global_position
	to.y = 0.0
	var dist := to.length()
	if dist > 0.01:
		facing = to / dist
	var reach := attack_reach() + _target.body_radius * 0.5
	if _attack_cooldown <= 0.0 and (_has_token or Combat.take_token(_target, self)):
		_has_token = true
		if dist > reach:
			velocity = facing * speed
		else:
			_start_attack()
		return
	# pas son tour : il tourne autour de sa cible en gardant ses distances
	_orbit_timer -= delta
	if _orbit_timer <= 0.0:
		_orbit_timer = randf_range(1.5, 3.0)
		_orbit_dir = -_orbit_dir if randf() < 0.4 else _orbit_dir
	var ring := reach + 1.6
	var side := facing.cross(Vector3.UP) * _orbit_dir
	var radial := facing * clampf(dist - ring, -1.0, 1.0)
	velocity = (side * 0.55 + radial).normalized() * speed * 0.45 if (side * 0.55 + radial).length() > 0.05 else Vector3.ZERO


func _wander(delta: float, speed: float) -> void:
	var to := _wander_to - global_position
	to.y = 0.0
	var run := speed * (1.0 if _returning else 0.35)
	if to.length() > 0.3:
		facing = to.normalized()
		velocity = facing * run
	else:
		_returning = false
		_pause -= delta
		if _pause <= 0.0:
			_pause = randf_range(1.5, 4.0)
			var off := Vector2.from_angle(randf() * TAU) * randf_range(0.5, 4.0)
			_wander_to = home + Vector3(off.x, 0, off.y)


func _choose_target() -> void:
	var range_home := data.leash_range if data else 18.0
	if _target:
		var lost := not is_instance_valid(_target) or not _target.can_be_targeted() \
				or global_position.distance_to(home) > range_home \
				or _target.global_position.distance_to(global_position) > (data.aggro_range if data else 9.0) * 1.8
		if lost:
			_release_token()
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


## Terrorisé : fuit le héros pendant `time` secondes.
func frighten(time: float) -> void:
	_fear_left = time
	_release_token()
	Combat.popup(self, global_position + Vector3(0, name_label.position.y + 0.2, 0), "Terrorisé", Color("c0a0ff"))


func _on_hurt(_amount: int, source: Node) -> void:
	# riposte contre celui qui l'a frappé (même un sort lancé de loin)
	var src := _attacker_of(source)
	if src and src.is_alive() and src != _target:
		_release_token()
		_target = src
		_returning = false


func _on_died() -> void:
	super()
	_release_token()
	collision_layer = 0
	name_label.visible = false
	bar.visible = false
	var c := data.color if data else Color.WHITE
	VoxelBurst.spawn(self, global_position + Vector3(0, 0.8, 0), c.darkened(0.2), 36, 5.0, 0.13, 0.9, "sphere", 12.0, false)
	VoxelBurst.spawn(self, global_position + Vector3(0, 0.8, 0), Color(1, 1, 0.9), 16, 6.0, 0.07, 0.4)
	_drop_loot()
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_method("on_enemy_killed"):
		player.on_enemy_killed(self)
	if player and player.has_method("gain_xp") and data:
		player.gain_xp(roundi((data.xp_reward if data.xp_reward > 0 else data.max_health / 4.0 + data.attack) * power))
	died_at.emit(global_position)


func _drop_loot() -> void:
	if data == null:
		return
	var world := get_tree().get_first_node_in_group("world") as WorldGenerator
	if world == null:
		return
	var n := 0
	var player := get_tree().get_first_node_in_group("player")
	var mult: float = player.loot_multiplier() if player and player.has_method("loot_multiplier") else 1.0
	for i in data.loot.size():
		var chance := minf(1.0, (data.loot_chances[i] if i < data.loot_chances.size() else 0.5) * mult)
		if randf() < chance:
			var a := TAU * n / 5.0 + randf() * 0.5
			world.spawn_pickup(data.loot[i], global_position + Vector3(cos(a), 0, sin(a)) * 0.9, 1, get_parent())
			n += 1
