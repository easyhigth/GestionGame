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
## Vitesse multipliée (failles « rapides »).
var speed_mult := 1.0

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
## Familier : monstre apprivoisé par le Pacte (voir Familiars) ; il suit le héros et combat avec lui.
var tamed := false
var familiar_name := ""
var familiar_title := ""
var familiar_slot := 0
## Ordre du familier : « suivre », « attendre » (reste à familiar_home), « attaquer » (la cible du héros),
## « village » (vit au village et le défend).
var familiar_order := "suivre"
var familiar_home := Vector3.INF
var _stuck_time := 0.0
## Monstre de la Brume (donjons de fin de jeu) : nom « Brumeux », couleur violette.
var brume := false
var _stuck_from := Vector3.ZERO

@onready var name_label: Label3D = $Name
@onready var bar: HealthBar3D = $HealthBar


func _ready() -> void:
	team = Team.ALLIES if tamed else Team.ENEMIES
	# pas d'invulnérabilité après un coup : les combos du joueur s'enchaînent
	hit_invulnerability = 0.0
	if data:
		poise_max = data.poise
	super()
	add_to_group("familiars" if tamed else "enemy_units")
	home = global_position
	_wander_to = home
	var eg := get_tree().get_first_node_in_group("endgame")
	if eg and not tamed:
		eg.scale_enemy(self)
	if data:
		_apply_data()


func _apply_data() -> void:
	visual.set_equipment_library(data.equipment_library)
	visual.set_model(_model_scene())
	visual.scale = Vector3.ONE * data.model_scale
	visual.trail_color = Color(data.color, 1.0).lightened(0.3)
	body_radius = data.body_radius
	for it in data.equipment:
		equipment.equip(it)
	health.set_max(roundi(data.max_health * power * (1.0 if tamed else SaveGame.enemy_hp_mult())), true)
	name_label.text = _label_base()
	name_label.modulate = _label_color()
	if tamed:
		visual.scale = Vector3.ONE * data.model_scale * Familiars.SCALE[clampi(get_meta("evo", 0), 0, 2)]
		name_label.text = "✦ %s · %s · Nv %d" % [familiar_name, familiar_title if familiar_title != "" else data.display_name, level]
		name_label.modulate = Color("b8f0a0")
	name_label.position.y = 2.1 * data.model_scale if not visual.is_quadruped() else 1.5 * data.model_scale
	bar.position.y = name_label.position.y - 0.22


func _label_base() -> String:
	return ("Brumeux · " if brume and not has_method("wake") else "") + "%s · Nv %d" % [data.display_name, level]


func _label_color() -> Color:
	return Color("b48cff") if brume else data.color


## Le modèle (celui de son évolution pour un familier évolué : <modèle>_evoN.glb).
func _model_scene() -> PackedScene:
	var evo: int = get_meta("evo", 0) if tamed else 0
	if evo > 0 and data.model:
		var path := data.model.resource_path.get_basename() + "_evo%d.glb" % evo
		if ResourceLoader.exists(path):
			return load(path)
	return data.model


func base_attack() -> int:
	return roundi((data.attack if data else 8) * power * (1.0 if tamed else SaveGame.enemy_dmg_mult()))


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
		if is_instance_valid(_target):
			Combat.release_token(_target, self)
		_has_token = false


## Loin du héros et au calme, le monstre ne se calcule qu'un pas de physique sur 4 (avec le temps cumulé).
var _lod_far := false
var _lod_acc := 0.0
var _lod_check := randf() * 0.5
var _lod_phase := randi() % 4


func _physics_process(delta: float) -> void:
	_lod_check -= delta
	if _lod_check <= 0.0:
		_lod_check = 0.5
		var pl := get_tree().get_first_node_in_group("player") as Node3D
		_lod_far = pl != null and not tamed and _target == null and is_alive() and not has_meta("raider") \
				and pl.global_position.distance_squared_to(global_position) > 45.0 * 45.0
	if _lod_far:
		_lod_acc += delta
		if Engine.get_physics_frames() % 4 != _lod_phase:
			return
		delta = _lod_acc
		_lod_acc = 0.0
	elif _lod_acc > 0.0:
		_lod_acc = 0.0
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
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if tamed:
		_familiar_process(delta, player)
		return
	# loin du joueur et au calme : on ne calcule presque rien
	var player_dist := player.global_position.distance_to(global_position) if player else 0.0
	name_label.visible = player_dist < 12.0 or _target != null
	if player and _target == null and player_dist > 45.0 and not has_meta("raider"):
		return
	_think -= delta
	if _think <= 0.0:
		_think = 0.3
		_choose_target()
		_pact_hint(player_dist)
	var speed := (data.move_speed if data else 3.5) * speed_factor() * speed_mult
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


# ---------------------------------------------------------------- familier et Pacte

## Monstre affaibli près du héros : « [E] Pacte » pour l'apprivoiser.
func _pact_hint(player_dist: float) -> void:
	if data == null:
		return
	var base := _label_base()
	if player_dist < 4.0 and Familiars.can_tame(self):
		name_label.text = base + "\n[E] Pacte (apprivoiser)"
		name_label.modulate = Color("d8c0ff")
	elif name_label.text != base:
		name_label.text = base
		name_label.modulate = _label_color()


func _familiar_process(delta: float, player: Node3D) -> void:
	if player == null:
		return
	# monté par le héros : c'est la monture qui le déplace (voir Mounts)
	if has_meta("ridden"):
		name_label.visible = false
		return
	var stays := familiar_order in ["attendre", "village"] and familiar_home != Vector3.INF
	var anchor: Vector3 = familiar_home if stays else player.global_position
	name_label.visible = player.global_position.distance_to(global_position) < 14.0
	_think -= delta
	if _think <= 0.0:
		_think = 0.3
		home = anchor
		var far := anchor.distance_to(global_position)
		# bloqué (il ne se rapproche pas d'au moins 1 m en 1,5 s) ou trop loin : il rejoint sa place
		if _target == null and far > 5.0:
			_stuck_time += 0.3
			if far < _stuck_from.x - 1.0:
				_stuck_time = 0.0
				_stuck_from.x = far
		else:
			_stuck_time = 0.0
			_stuck_from.x = far
		if far > 35.0 or _stuck_time > 1.5:
			global_position = anchor + Vector3(1.5, 0.5, 1.5)
			_stuck_time = 0.0
			_stuck_from.x = 0.0
			_target = null
		var reach := {"suivre": 10.0, "attaquer": 14.0, "attendre": 8.0, "village": 18.0}.get(familiar_order, 10.0) as float
		if _target and (not is_instance_valid(_target) or not _target.is_alive() or not _target.can_be_targeted() \
				or _target.global_position.distance_to(anchor) > reach + 6.0):
			_release_token()
			_target = null
			if familiar_order == "attaquer":
				familiar_order = "suivre"
		if familiar_order == "attaquer":
			var lt = player.get("lock_target")
			if lt and is_instance_valid(lt) and lt.is_alive() and lt != _target:
				_release_token()
				_target = lt
		if _target == null:
			var t := nearest_hostile(reach, anchor)
			if t:
				_target = t
			elif health.current < health.max_health:
				health.heal(maxi(1, roundi(health.max_health * 0.03)))
	var speed := (data.move_speed if data else 3.5) * speed_factor() * speed_mult
	velocity = Vector3.ZERO
	if not can_act() or in_move():
		pass
	elif _target:
		_fight(delta, speed)
	else:
		# il rejoint sa place : à côté du héros, à son poste, ou il flâne au village
		var a := TAU * familiar_slot / 3.0 + 2.4
		var spot := anchor + Vector3(cos(a), 0, sin(a)) * (2.2 if not stays else 1.0)
		if familiar_order == "village":
			spot = anchor + Vector3(cos(a + Time.get_ticks_msec() * 0.0002), 0, sin(a + Time.get_ticks_msec() * 0.0002)) * 3.0
		var to := spot - global_position
		to.y = 0.0
		if to.length() > 0.8:
			facing = to.normalized()
			velocity = facing * speed * (1.25 if to.length() > 5.0 else (0.8 if not stays else 0.4))
	_move_on_ground(delta)
	visual.animate(delta, velocity, facing)


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
	var fm := get_tree().get_first_node_in_group("familiars_mgr")
	if tamed:
		# un familier ne meurt pas : il tombe K.O. et revient plus tard
		VoxelBurst.spawn(self, global_position + Vector3(0, 0.8, 0), Color("b8f0a0"), 24, 3.0, 0.1, 0.8, "up", 2.0, false)
		if fm:
			fm.on_familiar_down(self)
		return
	if fm:
		fm.on_enemy_died(self)
	var sq := get_tree().get_first_node_in_group("side_quests")
	if sq:
		sq.on_enemy_died(self)
	var ach := get_tree().get_first_node_in_group("achievements")
	if ach:
		ach.on_kill(self)
	var c := data.color if data else Color.WHITE
	VoxelBurst.spawn(self, global_position + Vector3(0, 0.8, 0), c.darkened(0.2), 36, 5.0, 0.13, 0.9, "sphere", 12.0, false)
	VoxelBurst.spawn(self, global_position + Vector3(0, 0.8, 0), Color(1, 1, 0.9), 16, 6.0, 0.07, 0.4)
	_drop_loot()
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_method("on_enemy_killed"):
		player.on_enemy_killed(self)
	var eg := get_tree().get_first_node_in_group("endgame")
	if eg:
		eg.on_enemy_died(self)
	if player and player.has_method("gain_xp") and data:
		var xm: float = eg.xp_mult() if eg and not has_meta("rift") and not has_meta("titan") else 1.0
		player.gain_xp(roundi((data.xp_reward if data.xp_reward > 0 else data.max_health / 4.0 + data.attack) * power * xm))
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
	# ressources ultra-rares
	var rare := RareDrops.roll_enemy(self, mult)
	for pair in rare:
		var a := TAU * n / 5.0 + randf() * 0.5
		world.spawn_pickup(pair[0], global_position + Vector3(cos(a), 0, sin(a)) * 1.1, pair[1], get_parent())
		n += 1
	if not rare.is_empty():
		RareDrops.announce(player as Player, rare)
