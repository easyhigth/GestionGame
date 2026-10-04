class_name Boss
extends Enemy
## Boss de donjon : un gros monstre avec des pouvoirs annoncés à l'avance (on a le temps de les esquiver)
## et une seconde phase quand il tombe sous la moitié de sa vie (plus rapide, plus de pouvoirs).
## Pouvoirs (voir RegionData.boss_powers) :
##   "onde"       : onde de choc autour de lui (un disque rouge se remplit, puis ça frappe : roule hors du cercle !)
##   "pluie"      : des projectiles tombent sur le héros et autour de lui
##   "invocation" : il appelle des monstres de sa région
##   "charge"     : il fonce sur le héros

signal phase_changed(phase: int)

const TELEGRAPH := Color(1.0, 0.25, 0.15)

## Titre affiché à son réveil.
var title := ""
var powers: PackedStringArray = PackedStringArray(["onde"])
## Monstres qu'il peut appeler.
var summons: Array[EnemyData] = []
## Il dort tant que le héros n'est pas entré dans sa salle.
var awake := false
var phase := 1
var _power_timer := 4.0
var _power_index := 0
var _adds: Array[Enemy] = []


func _ready() -> void:
	super()
	add_to_group("bosses")
	var shape := get_node_or_null("Collision") as CollisionShape3D
	if shape == null:
		for c in get_children():
			if c is CollisionShape3D:
				shape = c
	if shape and shape.shape is CapsuleShape3D and data:
		var cap := (shape.shape as CapsuleShape3D).duplicate() as CapsuleShape3D
		cap.radius = data.body_radius
		cap.height = maxf(cap.radius * 2.0 + 0.1, 1.4 * data.model_scale * 0.7)
		shape.shape = cap
		shape.position.y = cap.height * 0.5
	name_label.font_size = 34
	# un boss ne se laisse pas étourdir si facilement
	poise_max = data.poise if data else 400.0
	poise = poise_max


func wake() -> void:
	if awake:
		return
	awake = true
	_power_timer = 3.5
	visual.flash(Color(1, 0.3, 0.2, 0.8), 0.4)
	VoxelBurst.spawn(self, global_position + Vector3(0, 1.5, 0), data.color if data else Color.RED, 50, 7.0, 0.14, 1.0, "sphere", 6.0)


func _physics_process(delta: float) -> void:
	if not awake:
		_combat_step(delta)
		velocity = Vector3.ZERO
		visual.animate(delta, Vector3.ZERO, facing)
		name_label.visible = false
		return
	super(delta)
	if not is_alive():
		return
	name_label.visible = true
	if phase == 1 and health.ratio() <= 0.5:
		_enter_phase(2)
	elif phase == 2 and health.ratio() <= 0.25:
		_enter_phase(3)
	if phase == 3:
		_fury_fx(delta)
	_power_timer -= delta
	if _power_timer <= 0.0 and can_act() and not in_move() and _target:
		_power_timer = randf_range(5.5, 8.0) * [1.0, 1.0, 0.65, 0.5][phase]
		_use_power()


func _on_move_ended(n: String, interrupted: bool) -> void:
	super(n, interrupted)
	if phase >= 2:
		_attack_cooldown *= 0.6 if phase == 2 else 0.45


## Enchaîne ses pouvoirs dans l'ordre (en phase 2, il peut en lancer deux à la suite).
func _use_power() -> void:
	if powers.is_empty():
		return
	var pw := powers[_power_index % powers.size()]
	_power_index += 1
	match pw:
		"onde":
			_shockwave()
		"pluie":
			_rain()
		"invocation":
			if _adds.filter(func(a): return is_instance_valid(a) and a.is_alive()).size() < 3:
				_summon()
			else:
				_shockwave()
		"charge":
			_charge()
	if phase >= 2 and randf() < 0.35 and pw != "onde":
		_after(1.4, func(): if is_alive(): _shockwave())
	# phase 3 : il ajoute les lames en croix (quatre bandes rouges qui partent de lui)
	if phase == 3:
		_after(2.2, func(): if is_alive(): _cross_blades())


# ---------------------------------------------------------------- phases

## Changement de phase mis en scène : le boss rugit, devient intouchable un instant pendant que le temps
## ralentit, une onde le repousse... Phase 2 (la moitié de sa vie) : enragé, plus rapide. Phase 3 (le
## quart) : fureur, entouré de braises, pouvoirs deux fois plus fréquents et lames en croix.
func _enter_phase(n: int) -> void:
	phase = n
	cancel_move()
	_invulnerable_left = maxf(_invulnerable_left, 1.6)
	var col := Color(1, 0.3, 0.2) if n == 2 else Color(0.75, 0.15, 1.0)
	Sound.play("boss_roar", global_position + Vector3(0, 2, 0), 3.0 + n, 0.0)
	Sound.play("ult_boom", global_position, -2.0 + n, 0.0)
	visual.trail_color = col
	visual.flash(Color(col, 0.45), 0.3)
	TimeFX.slow_motion(0.35, 0.9)
	var h := 1.4 * (data.model_scale if data else 1.0)
	VoxelBurst.emit(self, global_position + Vector3(0, h, 0), {"palette": VoxelBurst.palette_of(col), "count": 70 + 30 * n, "speed": 9.0,
		"size": 0.13, "life": 1.0, "hdr": 2.0, "streak": 1.5, "gravity": 4.0})
	VoxelBurst.emit(self, global_position + Vector3(0, h, 0), {"palette": VoxelBurst.palette_of(col), "count": 40, "speed": 3.0,
		"size": 0.1, "life": 0.8, "mode": "implode", "radius": 5.0, "hdr": 1.8})
	SkillFX.ring(self, global_position, 7.0 + n, col, 0.7)
	SkillFX.light(self, global_position + Vector3(0, h, 0), col, 6.0, 10.0, 1.2)
	if n == 3:
		SkillFX.scorch(self, global_position, 4.0, 8.0)
	Combat.popup(self, global_position + Vector3(0, name_label.position.y + 0.6, 0), "ENRAGÉ !" if n == 2 else "FUREUR !", col.lightened(0.3), true)
	# l'onde du rugissement repousse ceux qui sont collés à lui (sans les blesser)
	for c in get_tree().get_nodes_in_group(hostile_group()):
		var cb := c as Combatant
		if cb and cb.is_alive() and cb.global_position.distance_to(global_position) < 4.5:
			var away := cb.global_position - global_position
			away.y = 0.0
			cb._knockback = away.normalized() * 10.0
	var hero := get_tree().get_first_node_in_group("player")
	if hero and hero.has_method("shake"):
		hero.shake(0.6)
	phase_changed.emit(n)
	_power_timer = 1.8


var _fury_t := 0.0


## Phase 3 : des braises violettes montent autour de lui.
func _fury_fx(delta: float) -> void:
	_fury_t -= delta
	if _fury_t > 0.0:
		return
	_fury_t = 0.25
	var r := 1.2 * (data.model_scale if data else 1.0)
	VoxelBurst.emit(self, global_position + Vector3(0, 0.2, 0), {"palette": [Color(0.75, 0.15, 1.0), Color(1, 0.35, 0.6), Color(0.4, 0.05, 0.6)],
		"count": 6, "speed": 1.6, "size": 0.08, "life": 1.0, "mode": "column", "radius": r, "hdr": 1.8, "gravity": -2.0, "drag": 1.0})


# ---------------------------------------------------------------- pouvoirs

## Appelle `cb` après `t` secondes (annulé si le boss disparaît).
func _after(t: float, cb: Callable) -> void:
	var tm := Timer.new()
	tm.one_shot = true
	tm.wait_time = maxf(t, 0.05)
	add_child(tm)
	tm.timeout.connect(cb)
	tm.timeout.connect(tm.queue_free)
	tm.start()


## Disque rouge qui se remplit, puis coup sur tous ceux qui sont dedans.
static func telegraph(from: Node, pos: Vector3, radius: float, time: float, color := TELEGRAPH) -> void:
	SkillFX.telegraph(from, pos, radius, time, color)


func _hit_area(center: Vector3, radius: float, mult: float, knock: float) -> void:
	for n in get_tree().get_nodes_in_group(hostile_group()):
		var c := n as Combatant
		if c == null or not c.is_alive():
			continue
		var d := Vector2(c.global_position.x - center.x, c.global_position.z - center.z).length()
		if d <= radius + c.body_radius and absf(c.global_position.y - center.y) < 3.0:
			if not c.receive_hit(roundi(attack_power() * mult), self, knock, 2.0):
				c.notify_near_miss(self)


func _shockwave() -> void:
	var radius := 4.6 if phase == 1 else 5.6
	var wind := 1.25 if phase == 1 else 1.0
	var center := global_position
	telegraph(self, center, radius, wind)
	visual.play_move("heavy_1", 0.6)
	Combat.popup(self, global_position + Vector3(0, name_label.position.y + 0.5, 0), "!!", Color("ff4a3a"), true)
	_after(wind, func():
		if not is_alive():
			return
		SkillFX.ring(self, center, radius, Color(1.0, 0.6, 0.3), 0.4)
		VoxelBurst.spawn(self, center + Vector3(0, 0.3, 0), Color(0.8, 0.7, 0.6), 40, 6.0, 0.12, 0.6, "ring", 8.0, false)
		var hero := get_tree().get_first_node_in_group("player")
		if hero and hero.has_method("shake"):
			hero.shake(0.35)
		_hit_area(center, radius, 1.5, 9.0))


func _rain() -> void:
	if _target == null:
		return
	var n := 5 if phase == 1 else 8
	var col := data.color if data else Color(1, 0.5, 0.2)
	for i in n:
		var off := Vector3.ZERO if i == 0 else Vector3(randf_range(-4.0, 4.0), 0, randf_range(-4.0, 4.0))
		var pos := _target.global_position + off
		if _world:
			pos.y = _world.ground_height_at(pos)
		var delay := 1.0 + i * 0.18
		telegraph(self, pos, 1.5, delay, col)
		_after(delay - 0.55, func():
			if not is_alive():
				return
			SkillFX.meteor(self, pos, col, 0.7, func():
				VoxelBurst.spawn(self, pos + Vector3(0, 0.3, 0), col, 16, 4.0, 0.1, 0.4)
				_hit_area(pos, 1.5, 0.9, 5.0), 0.55))
	visual.play_move("cast_1", 0.8)


func _summon() -> void:
	if summons.is_empty():
		_shockwave()
		return
	var scene := load("res://scenes/enemies/enemy.tscn") as PackedScene
	var n := 2 if phase == 1 else 3
	Combat.popup(self, global_position + Vector3(0, name_label.position.y + 0.5, 0), "À moi !", Color("ffb04a"), true)
	visual.play_move("cast_1", 0.8)
	for i in n:
		var e := scene.instantiate() as Enemy
		e.data = summons.pick_random()
		e.level = maxi(1, level - 3)
		e.power = maxf(1.0, power * 0.7)
		var a := TAU * i / n + randf() * 0.5
		var pos := global_position + Vector3(cos(a), 0, sin(a)) * 3.0
		if _world and not _world.is_walkable(pos):
			pos = global_position + Vector3(cos(a), 0, sin(a)) * 1.2
		get_parent().add_child(e)
		e.global_position = Vector3(pos.x, _world.ground_height_at(pos) if _world else pos.y, pos.z)
		e.home = global_position
		_adds.append(e)
		VoxelBurst.spawn(e, e.global_position + Vector3(0, 0.6, 0), Color(0.6, 0.3, 0.9), 20, 3.0, 0.1, 0.5)


## Quatre bandes rouges partent du boss (en croix, ou en X une fois sur deux), puis des lames d'énergie
## les parcourent : il faut se placer entre elles.
func _cross_blades() -> void:
	var center := global_position
	var rot := 0.0 if randf() < 0.5 else PI / 4.0
	var length := 10.0
	var wind := 1.1
	var col := Color(0.85, 0.2, 1.0)
	for i in 4:
		var d := Vector3(cos(rot + i * PI / 2.0), 0, sin(rot + i * PI / 2.0))
		SkillFX.telegraph(self, center, 0.75, wind, Color(0.9, 0.2, 0.6), d, length)
	visual.play_move("cast_1", 0.8)
	Combat.popup(self, global_position + Vector3(0, name_label.position.y + 0.5, 0), "!!", Color("ff4aff"), true)
	_after(wind, func():
		if not is_alive():
			return
		for i in 4:
			var d := Vector3(cos(rot + i * PI / 2.0), 0, sin(rot + i * PI / 2.0))
			VoxelBurst.emit(self, center + d * 1.5 + Vector3(0, 0.5, 0), {"palette": VoxelBurst.palette_of(col), "count": 30, "speed": 14.0,
				"size": 0.1, "life": 0.6, "mode": "cone", "dir": d, "spread": 6.0, "streak": 3.0, "hdr": 2.2, "gravity": 0.0, "drag": 0.5})
		for n in get_tree().get_nodes_in_group(hostile_group()):
			var c := n as Combatant
			if c == null or not c.is_alive():
				continue
			var off := c.global_position - center
			off.y = 0.0
			for i in 4:
				var d := Vector3(cos(rot + i * PI / 2.0), 0, sin(rot + i * PI / 2.0))
				var along := off.dot(d)
				if along > 0.0 and along < length and (off - d * along).length() < 0.75 + c.body_radius:
					if not c.receive_hit(roundi(attack_power() * 1.3), self, 8.0, 2.0):
						c.notify_near_miss(self)
					break
		var hero := get_tree().get_first_node_in_group("player")
		if hero and hero.has_method("shake"):
			hero.shake(0.3))


func _charge() -> void:
	if _target == null:
		return
	var to := _target.global_position - global_position
	to.y = 0.0
	if to.length() > 0.01:
		facing = to.normalized()
	telegraph(self, global_position + facing * 3.5, 1.2, 0.6)
	if not perform("charge_ram", 0.9, 1.4):
		_shockwave()


func _on_died() -> void:
	super()
	for a in _adds:
		if is_instance_valid(a) and a.is_alive():
			a.health.take_damage(a.health.current, self)
