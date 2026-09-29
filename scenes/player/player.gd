class_name Player
extends Combatant
## Personnage joueur. Combat en temps réel à la Zelda :
## - combo de 3 coups (le 3e est un coup final puissant), estoc en sortie de roulade ;
## - attaque chargée : garder le bouton appuyé, puis relâcher (attaque tournoyante) ;
## - roulade invulnérable ; esquiver au dernier moment = ESQUIVE PARFAITE (ralenti + rafale de coups) ;
## - garde (bouclier) ; lever la garde juste avant le coup = PARADE, puis CONTRE dévastateur ;
## - verrouillage de cible : la caméra et le personnage restent tournés vers l'ennemi.
## Change la race dans l'Inspecteur (propriété « race ») pour jouer n'importe quelle race.

signal dashed
## Un message à afficher (objet ramassé, équipé, fabriqué...).
signal notify(text: String)
## Le joueur veut ouvrir l'inventaire d'un personnage (lui-même ou un habitant proche).
signal open_inventory(target: Node)
## Grand message au centre de l'écran (« Parade ! », « Esquive parfaite ! »).
signal feat(text: String, color: Color)
## La cible verrouillée a changé (null = aucune).
signal lock_changed(target: Combatant)

@export var stats: PlayerStats
@export var race: RaceData
## Position de la caméra par rapport au joueur (en mètres).
@export var camera_offset: Vector3 = Vector3(0, 10, 10)
@export var camera_smoothing: float = 8.0
## Caméra plus proche pendant un verrouillage.
@export var lock_camera_offset: Vector3 = Vector3(0, 8, 8.5)

## Distance max pour parler à un habitant ou utiliser l'établi.
@export var interact_distance: float = 2.4
## Équipe automatiquement un objet ramassé si l'emplacement est vide.
@export var auto_equip: bool = true
## Temps avant de se relever au village après avoir été vaincu (secondes).
@export var respawn_delay: float = 4.0

@export_group("Combat")
## Distance max pour verrouiller une cible.
@export var lock_range: float = 14.0
## Temps à garder le bouton d'attaque appuyé pour charger l'attaque tournoyante (secondes).
@export var charge_time: float = 0.75
## Début de roulade pendant lequel une esquive est « parfaite » (secondes).
@export var perfect_dodge_window: float = 0.26
## Durée (temps réel) du ralenti après une esquive parfaite.
@export var perfect_dodge_slowmo: float = 1.4
## Temps pour déclencher le contre après une parade (secondes).
@export var counter_window: float = 1.2

@onready var camera: Camera3D = $Camera

## Le sac du joueur.
var inventory := Inventory.new()
## Vrai quand une fenêtre est ouverte (le joueur ne bouge plus).
var ui_open := false
## Cible verrouillée.
var lock_target: Combatant

var _dash_time := 0.0
var _dash_elapsed := 99.0
var _dash_cooldown_left := 0.0
var _dash_dir := Vector3.ZERO
var _respawn_left := 0.0
var _shake := 0.0
var _combo := 0
var _combo_reset := 0.0
var _queued := false
var _held := 0.0
var _charging := false
var _counter_ready := 0.0
var _flurry_until := 0
var _flurry_target: Combatant
var _perfect_cd := 0.0
var _ghost_timer := 0.0
var _reticle: Node3D


func _ready() -> void:
	poise_max = 999.0
	super()
	add_to_group("player")
	if stats == null:
		stats = PlayerStats.new()
	camera.top_level = true
	apply_race(race)
	health.set_max(race.max_health if race else stats.max_health, true)
	parried.connect(_on_parried)
	_make_reticle()
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


# ---------------------------------------------------------------- boucle

func _physics_process(delta: float) -> void:
	_combat_step(delta)
	_dash_cooldown_left = maxf(_dash_cooldown_left - delta, 0.0)
	_dash_elapsed += delta
	_counter_ready = maxf(_counter_ready - delta, 0.0)
	_perfect_cd = maxf(_perfect_cd - delta, 0.0)
	_combo_reset -= delta
	if _combo_reset <= 0.0 and not in_move():
		_combo = 0
	if not is_alive():
		_respawn_left -= delta
		velocity = Vector3.ZERO
		_move_on_ground(delta)
		visual.animate(delta, Vector3.ZERO, facing)
		_update_camera(delta)
		if _respawn_left <= 0.0:
			_respawn()
		return
	_update_lock()

	var can_input := not ui_open
	var input2 := Input.get_vector("move_left", "move_right", "move_up", "move_down") if can_input else Vector2.ZERO
	var input := Vector3(input2.x, 0, input2.y)
	if input.length() > 1.0:
		input = input.normalized()
	var speed := stats.move_speed * (race.speed_multiplier if race else 1.0) * equipment.speed_multiplier()

	if can_input and can_act():
		_handle_combat_input(input, delta)

	if is_dashing():
		_dash_time -= delta
		velocity = _dash_dir * stats.dash_speed
		if TimeFX.is_slowed():
			_spawn_ghosts(delta)
		if not is_dashing():
			visual.set_trail(false)
	elif in_move() or not can_act():
		velocity = velocity.move_toward(Vector3.ZERO, stats.friction * delta)
	else:
		var horizontal := Vector3(velocity.x, 0, velocity.z)
		var max_speed := speed
		if blocking:
			max_speed *= 0.35
		elif _charging:
			max_speed *= 0.5
		elif lock_target:
			max_speed *= 0.8
		if input != Vector3.ZERO:
			if not lock_target and not blocking:
				facing = input
			horizontal = horizontal.move_toward(input * max_speed, stats.acceleration * delta)
		else:
			horizontal = horizontal.move_toward(Vector3.ZERO, stats.friction * delta)
		velocity = horizontal
	if lock_target and not is_dashing() and (not in_move() or move_t < 0.05):
		var to := lock_target.global_position - global_position
		to.y = 0.0
		if to.length() > 0.1:
			facing = to.normalized()

	if TimeFX.is_slowed() and in_move() and move_name == "flurry":
		_spawn_ghosts(delta)
	_move_on_ground(delta)
	visual.animate(delta, velocity, facing)
	_update_camera(delta)
	_update_reticle(delta)


func _handle_combat_input(input: Vector3, delta: float) -> void:
	# roulade (annule un coup en fin d'animation)
	if Input.is_action_just_pressed("dash") and _dash_cooldown_left <= 0.0 and not is_dashing() and can_cancel():
		_stop_charge()
		set_blocking(false)
		cancel_move()
		_start_dash(input if input != Vector3.ZERO else facing)
		return
	# garde / parade
	var guard := Input.is_action_pressed("block")
	if guard and not in_move() and not is_dashing():
		if Input.is_action_just_pressed("block") or not blocking:
			set_blocking(true)
			if not Input.is_action_just_pressed("block"):
				_block_time = 1.0  # garde tenue : pas de parade sans nouvel appui
	elif blocking:
		set_blocking(false)
	# attaque
	var pressed := Input.is_action_just_pressed("attack")
	var held := Input.is_action_pressed("attack")
	if pressed:
		_attack_pressed()
	if _charging:
		_held += delta
		visual.set_weapon_glow(clampf(_held / charge_time, 0.0, 1.0))
		if not held:
			if _held >= charge_time:
				_stop_charge()
				_do_move("spin", 1.0, 1.0)
				feat.emit("Attaque tournoyante !", Color("ffd86a"))
			else:
				_stop_charge()
	elif held and not in_move() and not blocking and not is_dashing() and weapon_style() != ItemData.WeaponStyle.STAFF:
		_held += delta
		if _held > 0.22:
			_charging = true
			visual.play_move("charge")
	elif not held:
		_held = 0.0
	# enchaînement mémorisé
	if _queued and can_chain():
		_queued = false
		_next_combo()


func _attack_pressed() -> void:
	_held = 0.0
	if blocking:
		set_blocking(false)
	# riposte après une esquive parfaite
	if Time.get_ticks_msec() < _flurry_until and _flurry_target and _flurry_target.is_alive():
		_flurry_until = 0
		_do_flurry()
		return
	# contre après une parade
	if _counter_ready > 0.0:
		_counter_ready = 0.0
		cancel_move()
		_do_move("counter", 1.1, 1.0)
		feat.emit("Contre !", Color("ffb040"))
		return
	# estoc en sortie de roulade
	if (is_dashing() or _dash_elapsed < 0.18) and weapon_style() != ItemData.WeaponStyle.STAFF:
		_dash_time = 0.0
		visual.set_trail(false)
		_do_move("dash_thrust", 1.0, 1.0)
		return
	if in_move():
		if can_chain():
			_next_combo()
		elif move_t > float(_move.get("combo", 0.0)) - 0.3:
			_queued = true
		return
	_combo = 0
	_next_combo()


func _next_combo() -> void:
	var list := MoveLibrary.combo_for(weapon_style())
	var name: String = list[_combo % list.size()]
	_combo += 1
	_combo_reset = 0.7
	_aim_assist()
	_do_move(name, attack_speed(), 1.0)


func _do_move(name: String, speed: float, dmg: float) -> void:
	if in_move():
		cancel_move()
	perform(name, speed, dmg)


func _stop_charge() -> void:
	if _charging:
		_charging = false
		visual.stop_move()
	visual.set_weapon_glow(0.0)
	_held = 0.0


## Se tourne vers l'ennemi le plus proche s'il est presque en face (aide à viser).
func _aim_assist() -> void:
	if lock_target:
		return
	var reach := minf(attack_reach(), 8.0) + 1.5
	var enemy := nearest_hostile(reach)
	if enemy == null:
		return
	var to := enemy.global_position - global_position
	to.y = 0.0
	if to.length() > 0.01 and absf(Vector2(facing.x, facing.z).angle_to(Vector2(to.x, to.z))) < deg_to_rad(75.0):
		facing = to.normalized()
		visual.rotation.y = atan2(facing.x, facing.z)


func _on_attack_landed(hits: int, hit: Dictionary) -> void:
	if hits <= 0:
		return
	var heavy := float(hit.get("dmg", 1.0)) >= 1.5
	TimeFX.hit_stop(0.09 if heavy else 0.045)
	shake(1.0 if heavy else 0.5)


# ---------------------------------------------------------------- défense

func _on_hurt(amount: int, _source: Node) -> void:
	shake(0.8 + amount * 0.04)
	_stop_charge()
	cancel_move()


## Un coup vient d'être esquivé pendant la roulade : si c'est au dernier moment, esquive parfaite.
func _on_evaded(attacker: Combatant) -> void:
	if not is_dashing() or _dash_elapsed > perfect_dodge_window or _perfect_cd > 0.0 or attacker == null:
		return
	_perfect_cd = 2.0
	_flurry_target = attacker
	_flurry_until = Time.get_ticks_msec() + roundi(perfect_dodge_slowmo * 1000.0)
	TimeFX.slow_motion(0.25, perfect_dodge_slowmo)
	visual.set_trail(true, Color(0.45, 0.85, 1.0))
	feat.emit("Esquive parfaite !", Color("7fd8ff"))
	VoxelBurst.spawn(self, global_position + Vector3(0, 1.0, 0), Color(0.5, 0.85, 1.0), 24, 4.0, 0.08, 0.5, "ring", 0.0)


func _on_parried(attacker: Combatant) -> void:
	_counter_ready = counter_window
	TimeFX.hit_stop(0.14)
	TimeFX.slow_motion(0.45, 0.5)
	shake(1.2)
	feat.emit("Parade !", Color("ffe27a"))
	if attacker and lock_target == null:
		_set_lock(attacker)


## Riposte après une esquive parfaite : on se précipite sur l'ennemi et on enchaîne les coups.
func _do_flurry() -> void:
	var t := _flurry_target
	var to := t.global_position - global_position
	to.y = 0.0
	var dir := to.normalized() if to.length() > 0.01 else facing
	visual.spawn_afterimage(Color(0.4, 0.8, 1.0, 0.6), 0.5)
	global_position = t.global_position - dir * (t.body_radius + 1.0)
	facing = dir
	visual.rotation.y = atan2(dir.x, dir.z)
	_do_move("flurry", 1.2, 1.0)
	TimeFX.slow_motion(0.35, 0.9)
	feat.emit("Riposte !", Color("7fd8ff"))


func _spawn_ghosts(delta: float) -> void:
	_ghost_timer -= delta
	if _ghost_timer <= 0.0:
		_ghost_timer = 0.03
		visual.spawn_afterimage(Color(0.4, 0.8, 1.0, 0.45), 0.35)


func _on_died() -> void:
	super()
	_respawn_left = respawn_delay
	_dash_time = 0.0
	_set_lock(null)
	_stop_charge()
	TimeFX.cancel()
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
	_dash_elapsed = 0.0
	_dash_cooldown_left = stats.dash_cooldown
	visual.play_roll(stats.dash_duration)
	dashed.emit()


# ---------------------------------------------------------------- verrouillage de cible

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
	elif event.is_action_pressed("lock_on"):
		if lock_target:
			# un nouvel appui passe à la cible suivante, ou relâche s'il n'y en a pas d'autre
			var next := _find_lock_target(lock_target)
			_set_lock(next)
		else:
			_set_lock(_find_lock_target(null))
		get_viewport().set_input_as_handled()


func _find_lock_target(exclude: Combatant) -> Combatant:
	var best: Combatant = null
	var best_score := INF
	for n in get_tree().get_nodes_in_group(hostile_group()):
		var c := n as Combatant
		if c == null or c == exclude or not c.is_alive():
			continue
		var to := c.global_position - global_position
		to.y = 0.0
		var d := to.length()
		if d > lock_range:
			continue
		var ang := absf(Vector2(facing.x, facing.z).angle_to(Vector2(to.x, to.z)))
		var score := d + ang * 3.0
		if score < best_score:
			best_score = score
			best = c
	return best


func _set_lock(t: Combatant) -> void:
	lock_target = t
	lock_changed.emit(t)


func _update_lock() -> void:
	if lock_target == null:
		return
	if not is_instance_valid(lock_target) or not lock_target.is_alive() \
			or lock_target.global_position.distance_to(global_position) > lock_range * 1.4:
		_set_lock(_find_lock_target(null) if is_instance_valid(lock_target) else null)


func _make_reticle() -> void:
	# cercle de crochets au sol + flèche au-dessus de la cible
	_reticle = Node3D.new()
	_reticle.top_level = true
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.4, 0.25)
	mat.no_depth_test = true
	mat.render_priority = 8
	var ring := Node3D.new()
	ring.name = "Ring"
	_reticle.add_child(ring)
	for i in 4:
		var arm := Node3D.new()
		arm.rotation.y = TAU * i / 4.0 + PI / 4.0
		for j in 3:
			var c := MeshInstance3D.new()
			var b := BoxMesh.new()
			b.size = Vector3(0.07, 0.03, 0.07)
			c.mesh = b
			c.material_override = mat
			c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			c.position = Vector3(1.0, 0, (j - 1) * 0.1)
			arm.add_child(c)
		ring.add_child(arm)
	var arrow := Node3D.new()
	arrow.name = "Arrow"
	for j in 3:
		var c := MeshInstance3D.new()
		var b := BoxMesh.new()
		var w := 0.2 - j * 0.07
		b.size = Vector3(w, 0.06, w)
		c.mesh = b
		c.material_override = mat
		c.position = Vector3(0, -j * 0.06, 0)
		arrow.add_child(c)
	_reticle.add_child(arrow)
	add_child(_reticle)
	_reticle.visible = false


func _update_reticle(delta: float) -> void:
	_reticle.visible = lock_target != null
	if lock_target == null:
		return
	var s := lock_target.visual.scale.y
	_reticle.global_position = lock_target.global_position
	var ring := _reticle.get_node("Ring") as Node3D
	ring.position.y = 0.06
	ring.rotation.y += delta * 1.5
	ring.scale = Vector3.ONE * (lock_target.body_radius + 0.35) * (1.0 + 0.06 * sin(Time.get_ticks_msec() * 0.008))
	var arrow := _reticle.get_node("Arrow") as Node3D
	var top := 2.55 * s if not lock_target.visual.is_quadruped() else 1.9 * s
	arrow.position.y = top + 0.08 * sin(Time.get_ticks_msec() * 0.006)


func _update_camera(delta: float) -> void:
	var offset := camera_offset
	var focus := global_position
	if lock_target and is_instance_valid(lock_target):
		offset = lock_camera_offset
		focus = global_position.lerp(lock_target.global_position, 0.35)
	var target := focus + offset
	camera.global_position = camera.global_position.lerp(target, clampf(camera_smoothing * delta, 0.0, 1.0))
	camera.look_at(camera.global_position - offset + Vector3(0, 0.8, 0))
	if _shake > 0.0:
		camera.global_position += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * _shake * 0.1
		_shake = maxf(_shake - delta * 4.0, 0.0)


# ---------------------------------------------------------------- village, objets

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
