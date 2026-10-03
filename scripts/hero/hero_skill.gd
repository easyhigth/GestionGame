class_name HeroSkill
extends RefCounted
## La compétence unique du héros pendant la partie : rang actuel, recharge, bonus temporaires,
## et exécution des effets actifs et passifs décrits par un SkillData.

signal activated
signal evolved(old_name: String, new_name: String, tier: int)

var data: SkillData
var owner: Player
var tier := 0
var cooldown_left := 0.0
## Bonus temporaires : clé -> [valeur, temps restant]
var buffs := {}
## Force absorbée (compétences d'absorption), pour toujours.
var absorbed := {"attack": 0, "magic": 0, "health": 0}

var _last_stand_cd := 0.0
var _barrier_left := 0.0
var _barrier_reduce := 0.0
var _barrier_reflect := false
var _fx_timer := 0.0
var _fields: Array = []   # zones actives : {pos, radius, dur, dps, slow, follow, tick}


func _init(skill: SkillData, hero: Player) -> void:
	data = skill
	owner = hero


func current_name() -> String:
	return data.tier_name(tier)


func set_level(level: int) -> void:
	var t := SkillData.tier_for_level(level)
	if t > tier:
		var old := current_name()
		tier = t
		evolved.emit(old, current_name(), tier)
	tier = t


# ---------------------------------------------------------------- passifs

## Bonus des talents passifs (arbre de talents), ajoutés aux passifs de la compétence.
var talent_bonus := {}


func p(key: String) -> float:
	var v := data.passive_value(key, tier) + float(talent_bonus.get(key, 0.0))
	if buffs.has(key):
		v += float(buffs[key][0])
	return v


func atk_mult() -> float:
	return 1.0 + p("atk_pct") + _buff("atk")


func mag_mult() -> float:
	return 1.0 + p("mag_pct")


func hp_mult() -> float:
	return 1.0 + p("hp_pct")


func speed_mult() -> float:
	return 1.0 + p("spd_pct") + _buff("spd")


func aspd_mult() -> float:
	return 1.0 + p("aspd_pct") + _buff("aspd")


func def_bonus() -> int:
	return roundi(p("def_flat") + _buff("def"))


func crit_chance() -> float:
	return minf(0.8, p("crit") + _buff("crit"))


func lifesteal() -> float:
	return p("lifesteal") + _buff("lifesteal")


func _buff(key: String) -> float:
	return float(buffs[key][0]) if buffs.has(key) and not data.passive.has(key) else 0.0


## Réduction des dégâts reçus (barrière).
func incoming_multiplier() -> float:
	return 1.0 - _barrier_reduce if _barrier_left > 0.0 else 1.0


## Bonus de dégâts contre une cible (rage, exécution).
func outgoing_multiplier(target: Combatant) -> float:
	var m := 1.0
	if owner.health.ratio() < 0.35:
		m += p("berserk")
	if target and target.health.ratio() < 0.3:
		m += p("execute")
	return m


func on_damage_dealt(target: Combatant, dmg: int) -> void:
	var ls := lifesteal()
	if ls > 0.0:
		owner.health.heal(maxi(1, roundi(dmg * ls)))
	if not target.is_alive():
		return
	var burn := p("burn") + _buff("burn")
	if burn > 0.0 and randf() < minf(burn, 0.9):
		target.apply_dot(maxf(2.0, _power() * 0.15), 3.0, owner, data.color)
	if p("stun") > 0.0 and randf() < minf(p("stun"), 0.5) and not target.is_staggered():
		target.stagger(1.0, true)
	if p("slow") > 0.0 and randf() < minf(p("slow"), 0.8):
		target.apply_slow(0.5, 2.5)


func on_kill(enemy: Combatant) -> void:
	if p("kill_heal") > 0.0:
		owner.health.heal(roundi(p("kill_heal")))
	if p("absorb") > 0.0 and randf() < minf(p("absorb"), 0.9):
		var what := ["attack", "magic", "health"].pick_random() as String
		absorbed[what] += 3 if what == "health" else 1
		var label := {"attack": "+1 Attaque", "magic": "+1 Magie", "health": "+3 Vie max"}[what] as String
		Combat.popup(owner, owner.global_position + Vector3(0, 2.6, 0), "Absorbé : " + label, data.color.lightened(0.3), true)
		VoxelBurst.spawn(owner, enemy.global_position + Vector3(0, 0.8, 0), data.color, 18, 3.0, 0.1, 0.6, "up", -2.0)
		owner.refresh_stats()


## Épines : renvoie une part des dégâts reçus.
func on_hurt(amount: int, source: Node) -> void:
	var t := p("thorns") + (0.5 if _barrier_reflect and _barrier_left > 0.0 else 0.0)
	var attacker := owner._attacker_of(source) if source else null
	if t > 0.0 and attacker and attacker.is_alive():
		var back := maxi(1, roundi(amount * t))
		attacker.health.take_damage(back, owner)
		Combat.popup(attacker, attacker.global_position + Vector3(0, 1.8, 0), str(back), data.color.lightened(0.3))


## Vrai si la compétence sauve le héros d'un coup mortel.
func try_last_stand() -> bool:
	if p("last_stand") <= 0.0 or _last_stand_cd > 0.0:
		return false
	_last_stand_cd = 60.0
	return true


# ---------------------------------------------------------------- mise à jour

func process(delta: float) -> void:
	cooldown_left = maxf(cooldown_left - delta, 0.0)
	_last_stand_cd = maxf(_last_stand_cd - delta, 0.0)
	_barrier_left = maxf(_barrier_left - delta, 0.0)
	for k in buffs.keys():
		buffs[k][1] -= delta
		if buffs[k][1] <= 0.0:
			buffs.erase(k)
			owner.refresh_stats()
	if not buffs.is_empty():
		_fx_timer -= delta
		if _fx_timer <= 0.0:
			_fx_timer = 0.25
			VoxelBurst.spawn(owner, owner.global_position + Vector3(randf_range(-0.4, 0.4), 0.2, randf_range(-0.4, 0.4)), data.color, 3, 1.5, 0.08, 0.6, "up", -3.0)
	# zones (dégâts continus, ralentissement, auras)
	var i := 0
	while i < _fields.size():
		var f: Dictionary = _fields[i]
		f.dur -= delta
		f.tick -= delta
		var center: Vector3 = owner.global_position if f.follow else f.pos
		if f.tick <= 0.0:
			f.tick = 0.5
			for e in _enemies(center, f.radius):
				if f.dps > 0.0:
					e.health.take_damage(maxi(1, roundi(f.dps * 0.5)), owner)
					Combat.popup(e, e.global_position + Vector3(0, 1.6, 0), str(maxi(1, roundi(f.dps * 0.5))), data.color.lightened(0.3))
				if f.slow > 0.0:
					e.apply_slow(f.slow, 0.8)
		if f.dur <= 0.0:
			_fields.remove_at(i)
		else:
			i += 1


func cooldown_ratio() -> float:
	var total: float = data.cooldown * SkillData.CD_SCALE[tier] * (1.0 - clampf(p("cdr_pct"), 0.0, 0.6))
	return cooldown_left / maxf(total, 0.01)


# ---------------------------------------------------------------- effet actif

func activate() -> bool:
	if cooldown_left > 0.0 or not owner.is_alive():
		return false
	var kind := data.active
	var prm := data.active_params
	if kind == "random":
		var pool := [["nova", {"radius": 3.5, "dmg": 1.6}], ["volley", {"count": 5, "dmg": 0.9, "spread": 1.0}],
			["meteor", {"radius": 3.0, "dmg": 1.8, "count": 2}], ["stun", {"radius": 4.5, "dur": 2.0}],
			["vortex", {"radius": 5.0, "dmg": 1.2}], ["cone", {"range": 6.0, "dmg": 1.4, "kb": 12, "angle": 90}],
			["heal", {"pct": 0.3}], ["aura", {"radius": 2.6, "dps": 0.6, "dur": 4}]]
		var pick: Array = pool.pick_random()
		kind = pick[0]
		prm = pick[1]
	if data.category == "mystique":
		_mythic_intro(prm)
	call("_a_" + kind, prm)
	Sound.play("cast", owner.global_position + Vector3(0, 1, 0), -2.0)
	cooldown_left = data.cooldown * SkillData.CD_SCALE[tier] * (1.0 - clampf(p("cdr_pct"), 0.0, 0.6))
	owner.visual.flash(Color(data.color, 0.4), 0.15)
	owner.feat.emit(("✦ " + current_name() + " ✦") if data.category == "mystique" else current_name() + " !", data.color.lightened(0.25))
	activated.emit()
	return true


func _tfx() -> Node:
	return owner.get_tree().root.get_node("TimeFX")


func _power() -> float:
	return float(maxi(owner.attack_power(), owner.magic_power()))


func _dmg(prm: Dictionary) -> float:
	return _power() * float(prm.get("dmg", 1.0)) * SkillData.DMG_SCALE[tier]


func _radius(prm: Dictionary, key := "radius", def := 3.0) -> float:
	return float(prm.get(key, def)) * SkillData.RADIUS_SCALE[tier]


func _dur(prm: Dictionary, def := 3.0) -> float:
	return float(prm.get("dur", def)) * SkillData.DUR_SCALE[tier]


func _enemies(center: Vector3, radius: float) -> Array:
	var out := []
	for n in owner.get_tree().get_nodes_in_group(owner.hostile_group()):
		var c := n as Combatant
		if c and c.is_alive() and Vector2(c.global_position.x - center.x, c.global_position.z - center.z).length() <= radius + c.body_radius:
			out.append(c)
	return out


func _hit(target: Combatant, amount: float, kb := 4.0, prm := {}) -> void:
	if target.receive_hit(roundi(amount), owner, kb, 1.5):
		if prm.has("burn") and randf() < float(prm["burn"]) + 0.3:
			target.apply_dot(maxf(2.0, _power() * 0.2), 3.0, owner, data.color)
		if prm.has("stun") and randf() < float(prm["stun"]):
			target.stagger(1.4, true)
		if prm.has("slow"):
			target.apply_slow(0.4, 3.0)


func _forward() -> Vector3:
	if owner.lock_target and is_instance_valid(owner.lock_target):
		var to := owner.lock_target.global_position - owner.global_position
		to.y = 0.0
		if to.length() > 0.1:
			return to.normalized()
	return Vector3(owner.facing.x, 0, owner.facing.z).normalized()


func _burst(pos: Vector3, count := 24, speed := 5.0) -> void:
	VoxelBurst.spawn(owner, pos + Vector3(0, 0.6, 0), data.color, count, speed, 0.12, 0.6)


func _a_nova(prm: Dictionary) -> void:
	var r := _radius(prm)
	var c := owner.global_position
	SkillFX.ring(owner, c, r, data.color, 0.4)
	_burst(c, 36, r * 2.0)
	_tfx().hit_stop(0.06)
	owner.shake(1.0)
	for e in _enemies(c, r):
		_hit(e, _dmg(prm), 7.0, prm)
	if prm.has("heal"):
		owner.health.heal(roundi(owner.health.max_health * float(prm["heal"])))
	# Fimbulvetr : un blizzard reste sur place
	if prm.has("field"):
		_a_slow_field({"radius": r * 0.6, "dps": 1.0, "factor": 0.3, "dur": 8})


func _a_volley(prm: Dictionary) -> void:
	var n := data._count(tier)
	var spread := float(prm.get("spread", 0.6))
	var fwd := _forward()
	for i in n:
		var bolt := MagicBolt.new()
		bolt.shooter = owner
		bolt.color = data.color
		var ang := (i - (n - 1) / 2.0) * (spread / maxf(1.0, n - 1.0)) if n > 1 else 0.0
		bolt.direction = fwd.rotated(Vector3.UP, ang)
		bolt.damage = roundi(_dmg(prm))
		bolt.range_left = 11.0
		bolt.speed = 15.0
		var extra := prm
		bolt.on_hit = func(t: Combatant):
			if extra.has("burn") and randf() < float(extra["burn"]) + 0.3:
				t.apply_dot(maxf(2.0, _power() * 0.2), 3.0, owner, data.color)
			if extra.has("stun") and randf() < float(extra["stun"]):
				t.stagger(1.2, true)
		SkillFX._holder(owner).add_child(bolt)
		bolt.global_position = owner.global_position + Vector3(0, 1.1, 0) + bolt.direction * 0.7


func _a_dash(prm: Dictionary) -> void:
	var fwd := _forward()
	var dist := _radius(prm, "dist", 6.0)
	var start := owner.global_position
	var world := owner.get_tree().get_first_node_in_group("world") as WorldGenerator
	var pos := start
	var steps := int(dist / 0.25)
	for s in steps:
		var nxt := pos + fwd * 0.25
		if world:
			nxt = world.constrain_move(pos, nxt)
		if nxt.distance_to(pos) < 0.05:
			break
		pos = nxt
		if s % 3 == 0:
			owner.visual.spawn_afterimage(Color(data.color, 0.5), 0.35)
			owner.visual.global_position = pos
	owner.global_position = pos
	owner.visual.position = Vector3.ZERO
	owner._invulnerable_left = 0.35
	var line := pos - start
	for e in owner.get_tree().get_nodes_in_group(owner.hostile_group()):
		var c := e as Combatant
		if c == null or not c.is_alive():
			continue
		var rel := c.global_position - start
		rel.y = 0.0
		var t := clampf(rel.dot(line) / maxf(line.length_squared(), 0.01), 0.0, 1.0)
		if (rel - line * t).length() < 1.3 + c.body_radius:
			_hit(c, _dmg(prm), 5.0, prm)
	_burst(pos, 20, 4.0)
	owner.shake(0.7)


func _a_heal(prm: Dictionary) -> void:
	var pct: float = float(prm.get("pct", 0.3)) * SkillData.HEAL_SCALE[tier]
	owner.health.heal(roundi(owner.health.max_health * pct))
	VoxelBurst.spawn(owner, owner.global_position + Vector3(0, 0.2, 0), data.color, 30, 2.5, 0.1, 1.0, "up", -2.0)
	SkillFX.ring(owner, owner.global_position, 2.5, data.color, 0.6)
	if prm.has("allies"):
		for v in owner.get_tree().get_nodes_in_group("villagers"):
			var c := v as Combatant
			if c and c.global_position.distance_to(owner.global_position) < 9.0:
				if not c.is_alive():
					c.health.revive(pct)
					c.visual.set_downed(false)
				else:
					c.health.heal(roundi(c.health.max_health * pct))
				VoxelBurst.spawn(owner, c.global_position + Vector3(0, 0.2, 0), data.color, 12, 2.0, 0.08, 0.8, "up", -2.0)


## Chant, bénédiction : renfort du héros, et les alliés proches (habitants, familiers) sont soignés.
func _a_rally(prm: Dictionary) -> void:
	_a_buff(prm)
	var pct := float(prm.get("heal", 0.1))
	SkillFX.ring(owner, owner.global_position, 9.0, data.color, 0.7)
	for g in ["villagers", "familiars"]:
		for n in owner.get_tree().get_nodes_in_group(g):
			var c := n as Combatant
			if c and c.is_alive() and c.global_position.distance_to(owner.global_position) < 9.0:
				c.health.heal(maxi(1, roundi(c.health.max_health * pct)))
				VoxelBurst.spawn(owner, c.global_position + Vector3(0, 0.2, 0), data.color, 10, 2.0, 0.08, 0.8, "up", -2.0)


## Nécromancien : des morts-vivants alliés sortent de terre et combattent pour le héros un moment.
func _a_summon(prm: Dictionary) -> void:
	var data_path := "res://data/enemies/%s.tres" % str(prm.get("monster", "squelette"))
	if not ResourceLoader.exists(data_path):
		return
	var n := int(prm.get("count", 2)) + tier
	var dur := _dur(prm, 30.0)
	var holder := owner.get_tree().get_first_node_in_group("familiars_mgr") as Node
	if holder == null:
		holder = owner.get_parent()
	# les anciens invoqués s'effacent
	for old in owner.get_tree().get_nodes_in_group("summons"):
		old.set_meta("summon_left", 0.0)
	for i in n:
		var e := (load("res://scenes/enemies/enemy.tscn") as PackedScene).instantiate() as Enemy
		e.tamed = true
		e.data = load(data_path) as EnemyData
		e.level = maxi(1, owner.level)
		e.power = 0.6 + 0.004 * owner.level + 0.002 * owner.magic_power()
		e.familiar_name = "Serviteur"
		e.familiar_title = "Mort-vivant invoqué"
		e.familiar_slot = 5 + i
		e.set_meta("summon_left", dur)
		e.add_to_group("summons")
		holder.add_child(e)
		var a := TAU * i / n
		var pos := owner.global_position + Vector3(cos(a), 0, sin(a)) * 1.8
		e.global_position = pos
		e.home = pos
		VoxelBurst.spawn(owner, pos + Vector3(0, 0.1, 0), data.color, 24, 2.5, 0.1, 1.0, "up", -1.0)


func _a_buff(prm: Dictionary) -> void:
	var dur := _dur(prm, 6.0)
	var s: float = SkillData.PASSIVE_SCALE[tier]
	for key in ["atk", "def", "spd", "aspd", "crit", "lifesteal", "burn"]:
		if prm.has(key):
			buffs[key] = [float(prm[key]) * (s if key != "def" else s), dur]
	if prm.has("cost"):
		owner.health.take_damage(maxi(1, roundi(owner.health.current * float(prm["cost"]))), owner)
	SkillFX.orbit(owner, data.color, dur, 0.8, 6)
	VoxelBurst.spawn(owner, owner.global_position + Vector3(0, 0.2, 0), data.color, 30, 3.0, 0.1, 0.8, "up", -1.0)
	owner.refresh_stats()


func _a_barrier(prm: Dictionary) -> void:
	var dur := _dur(prm, 4.0)
	_barrier_left = dur
	_barrier_reduce = clampf(float(prm.get("reduce", 0.5)) + 0.05 * tier, 0.0, 1.0)
	_barrier_reflect = prm.has("reflect")
	SkillFX.shell(owner, data.color, dur, 1.1)
	if prm.has("heal"):
		owner.health.heal(roundi(owner.health.max_health * float(prm["heal"])))


func _a_stun(prm: Dictionary) -> void:
	var r := _radius(prm, "radius", 4.0)
	# Fureur de Gaïa : des pics de roche jaillissent partout
	if str(prm.get("fx", "")) == "rocks":
		for i in 26:
			var a := randf() * TAU
			var pos := owner.global_position + Vector3(cos(a), 0, sin(a)) * randf_range(2.0, r)
			SkillFX.falling(owner, pos, Color("9a7a5a"), "spike", 1.3, func(): pass, 0.2 + i * 0.03)
	SkillFX.ring(owner, owner.global_position, r, data.color, 0.5)
	_burst(owner.global_position, 24, r * 1.5)
	for e in _enemies(owner.global_position, r):
		if prm.has("dmg"):
			_hit(e, _dmg(prm), 2.0)
		if e.is_alive():
			e.stagger(_dur(prm, 2.0), true)


func _a_vortex(prm: Dictionary) -> void:
	var r := _radius(prm, "radius", 5.0)
	var center := owner.global_position + _forward() * 2.5
	SkillFX.spiral(owner, center, r, data.color, 0.9)
	SkillFX.disc(owner, center, r, data.color, 1.0)
	var victims := _enemies(center, r)
	for e in victims:
		var to: Vector3 = center - e.global_position
		to.y = 0.0
		e._knockback = to * 3.0
	var dmg := _dmg(prm)
	owner.get_tree().create_timer(0.75, false).timeout.connect(func():
		if not is_instance_valid(owner):
			return
		VoxelBurst.spawn(owner, center + Vector3(0, 0.5, 0), data.color, 40, 6.0, 0.13, 0.6)
		SkillFX.ring(owner, center, r * 0.6, data.color, 0.35)
		owner.shake(1.0)
		for e in _enemies(center, r * 0.8):
			_hit(e, dmg, 3.0))


func _a_cone(prm: Dictionary) -> void:
	var fwd := _forward()
	var rng := _radius(prm, "range", 5.0)
	var ang := float(prm.get("angle", 90.0))
	var o := owner.global_position
	var b := VoxelBurst.new()
	b.color = data.color
	b.gravity = 0.0
	for i in 40:
		var a := deg_to_rad(randf_range(-ang, ang) * 0.5)
		var d := fwd.rotated(Vector3.UP, a)
		b._pos.append(o + Vector3(0, 0.9 + randf_range(-0.3, 0.3), 0) + d * 0.5)
		b._vel.append(d * rng * randf_range(1.8, 2.6))
		b._age.append(0.0)
		b._life.append(0.45)
		b._size.append(randf_range(0.12, 0.22))
		b._rot.append(Vector3(randf(), randf(), 0))
	SkillFX._holder(owner).add_child(b)
	owner.shake(0.7)
	for e in _enemies(o, rng):
		var to: Vector3 = e.global_position - o
		to.y = 0.0
		if to.length() < 0.5 or absf(rad_to_deg(Vector2(fwd.x, fwd.z).angle_to(Vector2(to.x, to.z)))) <= ang * 0.5:
			_hit(e, _dmg(prm), float(prm.get("kb", 6.0)), prm)


func _a_drain(prm: Dictionary) -> void:
	var r := _radius(prm, "radius", 4.0)
	var total := 0
	SkillFX.ring(owner, owner.global_position, r, data.color, 0.5)
	for e in _enemies(owner.global_position, r):
		var before: int = e.health.current
		_hit(e, _dmg(prm), 1.0)
		total += before - e.health.current
		VoxelBurst.spawn(owner, e.global_position + Vector3(0, 1.0, 0), data.color, 10, 2.0, 0.09, 0.5, "up", -4.0)
	if total > 0:
		owner.health.heal(maxi(1, roundi(total * float(prm.get("ratio", 0.5)))))
		VoxelBurst.spawn(owner, owner.global_position + Vector3(0, 0.3, 0), data.color, 20, 2.0, 0.09, 0.8, "up", -2.0)


func _a_meteor(prm: Dictionary) -> void:
	var n := int(prm.get("count", 1)) + tier
	var r := _radius(prm, "radius", 3.0)
	var targets := []
	if owner.lock_target and is_instance_valid(owner.lock_target):
		targets.append(owner.lock_target.global_position)
	var area := float(prm.get("area", 12.0))
	var near := _enemies(owner.global_position, area)
	near.sort_custom(func(a, b): return a.global_position.distance_to(owner.global_position) < b.global_position.distance_to(owner.global_position))
	for e in near:
		targets.append(e.global_position)
	while targets.size() < n:
		if prm.has("area"):
			var a := randf() * TAU
			targets.append(owner.global_position + Vector3(cos(a), 0, sin(a)) * randf_range(2.0, area))
		else:
			targets.append(owner.global_position + _forward() * (3.0 + targets.size() * 1.5) + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)))
	var dmg := _dmg(prm)
	for i in n:
		var pos: Vector3 = targets[i]
		var delay := 0.55 + i * 0.18
		SkillFX.meteor(owner, pos, data.color, 0.5 + r * 0.12, func():
			if not is_instance_valid(owner):
				return
			VoxelBurst.spawn(owner, pos + Vector3(0, 0.3, 0), data.color, 40, 6.0, 0.14, 0.7, "sphere", 12.0, false)
			SkillFX.ring(owner, pos, r, data.color.lightened(0.2), 0.4)
			_tfx().hit_stop(0.05)
			owner.shake(1.2)
			for e in _enemies(pos, r):
				_hit(e, dmg, 8.0, prm), delay)


func _a_dot(prm: Dictionary) -> void:
	var r := _radius(prm, "radius", 4.0)
	var dur := _dur(prm, 5.0)
	SkillFX.disc(owner, owner.global_position, r, data.color, dur)
	_burst(owner.global_position, 30, 3.0)
	_fields.append({"pos": owner.global_position, "radius": r, "dur": dur, "dps": _dmg({"dmg": float(prm.get("dps", 0.3)) * 2.0}), "slow": 0.0, "follow": false, "tick": 0.0})


func _a_slow_field(prm: Dictionary) -> void:
	var r := _radius(prm, "radius", 5.0)
	var dur := _dur(prm, 5.0)
	SkillFX.disc(owner, owner.global_position, r, data.color, dur)
	SkillFX.ring(owner, owner.global_position, r, data.color, 0.6)
	var dps := _dmg({"dmg": float(prm.get("dps", 0.0)) * 2.0}) if prm.has("dps") else 0.0
	_fields.append({"pos": owner.global_position, "radius": r, "dur": dur, "dps": dps, "slow": float(prm.get("factor", 0.4)), "follow": false, "tick": 0.0})


func _a_aura(prm: Dictionary) -> void:
	var r := _radius(prm, "radius", 2.5)
	var dur := _dur(prm, 5.0)
	SkillFX.orbit(owner, data.color, dur, r * 0.8, 10)
	_fields.append({"pos": owner.global_position, "radius": r, "dur": dur, "dps": _dmg({"dmg": float(prm.get("dps", 0.4)) * 2.0}), "slow": 0.0, "follow": true, "tick": 0.0})


func _a_fear(prm: Dictionary) -> void:
	var r := _radius(prm, "radius", 6.0)
	SkillFX.ring(owner, owner.global_position, r, data.color.darkened(0.3), 0.6)
	_burst(owner.global_position, 30, 4.0)
	owner.shake(0.8)
	for e in _enemies(owner.global_position, r):
		if prm.has("dmg"):
			_hit(e, _dmg(prm), 3.0)
		if e.is_alive() and e.has_method("frighten"):
			e.frighten(_dur(prm, 3.0))


func _a_execute(prm: Dictionary) -> void:
	var rng := _radius(prm, "range", 7.0)
	var target: Combatant = owner.lock_target if owner.lock_target and is_instance_valid(owner.lock_target) and owner.lock_target.is_alive() else null
	if target == null:
		var list := _enemies(owner.global_position, rng)
		list.sort_custom(func(a, b): return a.health.ratio() < b.health.ratio())
		target = list[0] if not list.is_empty() else null
	if target == null:
		_a_nova({"radius": 2.5, "dmg": prm.get("dmg", 1.5)})
		return
	var to := target.global_position - owner.global_position
	to.y = 0.0
	owner.visual.spawn_afterimage(Color(data.color, 0.5), 0.4)
	owner.global_position = target.global_position - to.normalized() * (target.body_radius + 0.9)
	owner.facing = to.normalized()
	owner.visual.rotation.y = atan2(to.x, to.z)
	var dmg := _dmg(prm)
	if target.health.ratio() <= float(prm.get("threshold", 0.3)):
		dmg *= 3.0
		Combat.popup(target, target.global_position + Vector3(0, 2.3, 0), "Exécution !", data.color.lightened(0.3), true)
	owner.perform("counter", 1.3, 0.0)
	_hit(target, dmg, 6.0)
	VoxelBurst.spawn(owner, target.global_position + Vector3(0, 1.0, 0), data.color, 30, 6.0, 0.1, 0.5)
	_tfx().hit_stop(0.1)
	owner.shake(1.3)


## Attaque du répertoire de mouvements (tourbillon...) avec un bonus de dégâts.
func _a_move(prm: Dictionary) -> void:
	owner._do_move(str(prm.get("move", "spin")), 1.0, float(prm.get("dmg", 1.0)) * SkillData.DMG_SCALE[tier])
	SkillFX.ring(owner, owner.global_position, 2.6, data.color, 0.35)


## Éclair en chaîne : frappe l'ennemi le plus proche puis rebondit sur les suivants.
func _a_chain(prm: Dictionary) -> void:
	var n := data._count(tier)
	var from := owner.global_position + Vector3(0, 1.1, 0)
	var first := owner.lock_target if owner.lock_target and is_instance_valid(owner.lock_target) and owner.lock_target.is_alive() else null
	var hit := []
	var cur: Combatant = first
	for i in n:
		if cur == null:
			var best: Combatant = null
			var bd := 9.0 if i == 0 else 5.5
			for e in _enemies(owner.global_position if i == 0 else from, bd):
				if hit.has(e):
					continue
				var d: float = e.global_position.distance_to(from)
				if d < bd:
					bd = d
					best = e
			cur = best
		if cur == null:
			break
		var to := cur.global_position + Vector3(0, 1.0, 0)
		# éclair : des étincelles le long du trait
		for k in 7:
			var pt := from.lerp(to, k / 6.0) + Vector3(randf_range(-0.15, 0.15), randf_range(-0.15, 0.15), randf_range(-0.15, 0.15))
			VoxelBurst.spawn(owner, pt, data.color.lightened(0.4), 3, 0.6, 0.09, 0.25, "sphere", 0.0)
		_hit(cur, _dmg(prm) * (1.0 - 0.12 * i), 3.0, prm)
		hit.append(cur)
		from = to
		cur = null
	if not hit.is_empty():
		_tfx().hit_stop(0.04)
		owner.shake(0.5)


func _a_blink(prm: Dictionary) -> void:
	var fwd := _forward()
	var dist := _radius(prm, "dist", 6.0)
	var world := owner.get_tree().get_first_node_in_group("world") as WorldGenerator
	var pos := owner.global_position
	owner.visual.spawn_afterimage(Color(data.color, 0.6), 0.5)
	VoxelBurst.spawn(owner, pos + Vector3(0, 0.9, 0), data.color, 16, 3.0, 0.1, 0.4)
	for s in int(dist / 0.25):
		var nxt := pos + fwd * 0.25
		if world:
			nxt = world.constrain_move(pos, nxt)
		if nxt.distance_to(pos) < 0.05:
			break
		pos = nxt
	owner.global_position = pos
	owner._invulnerable_left = 0.4
	VoxelBurst.spawn(owner, pos + Vector3(0, 0.9, 0), data.color, 20, 3.5, 0.1, 0.4)
	if prm.has("dmg"):
		SkillFX.ring(owner, pos, 2.5, data.color, 0.35)
		for e in _enemies(pos, 2.5):
			_hit(e, _dmg(prm), 5.0)


# ---------------------------------------------------------------- mystiques

## Mise en scène des compétences mystiques : le temps ralentit, une colonne de lumière monte du héros,
## l'écran s'illumine, des ondes de choc se succèdent et la terre tremble.
func _mythic_intro(prm: Dictionary) -> void:
	var c := owner.global_position
	var r := float(prm.get("radius", prm.get("area", 12.0)))
	_tfx().slow_motion(0.35, 1.1)
	SkillFX.pillar(owner, c, data.color.lightened(0.3), 40.0, 1.6, 1.4)
	SkillFX.screen_flash(owner, data.color.lightened(0.5), 0.7, 0.5)
	SkillFX.shockwave(owner, c, r, data.color, 4, 0.9)
	VoxelBurst.spawn(owner, c + Vector3(0, 0.4, 0), data.color, 120, 9.0, 0.16, 1.6, "up", -1.0)
	VoxelBurst.spawn(owner, c + Vector3(0, 0.2, 0), data.color.lightened(0.4), 80, r * 0.8, 0.14, 1.0, "ring", 0.0)
	owner.shake(2.2)
	Sound.ui("war_drums")


## Frappes venues du ciel sur les ennemis autour du héros (épées géantes, éclairs, colonnes de feu ou de
## lumière, pics de glace, lames d'ombre). `count` frappes ; s'il y a moins d'ennemis, le reste tombe autour.
func _a_storm(prm: Dictionary) -> void:
	var r := _radius(prm, "radius", 8.0)
	var n := int(prm.get("count", 6))
	var fx := str(prm.get("fx", "bolt"))
	var c := owner.global_position
	var foes := _enemies(c, r)
	foes.sort_custom(func(a, b): return a.global_position.distance_to(c) < b.global_position.distance_to(c))
	var points := []
	for e in foes:
		if points.size() >= n:
			break
		points.append(e.global_position)
	while points.size() < n:
		var a := randf() * TAU
		points.append(c + Vector3(cos(a), 0, sin(a)) * randf_range(2.0, r))
	var dmg := _dmg(prm)
	var hit_r := 2.4 if data.category != "mystique" else 3.4
	var step := 0.05 if n > 12 else 0.09
	for i in points.size():
		var pos: Vector3 = points[i]
		var world := owner.get_tree().get_first_node_in_group("world") as WorldGenerator
		if world and pos.y > WorldGenerator.UNDERGROUND:
			pos.y = world.support_height(pos, world.terrain_height(world.cell_at(pos)) + 0.4)
		var impact := func():
			if not is_instance_valid(owner):
				return
			VoxelBurst.spawn(owner, pos + Vector3(0, 0.4, 0), data.color, 22, 5.0, 0.12, 0.6, "sphere", 10.0, false)
			SkillFX.ring(owner, pos, hit_r, data.color.lightened(0.2), 0.35)
			for e in _enemies(pos, hit_r):
				_hit(e, dmg, float(prm.get("kb", 6.0)), prm)
				if prm.has("fear") and e.is_alive() and e.has_method("frighten"):
					e.frighten(float(prm.fear))
			owner.shake(0.6)
		var delay := 0.25 + i * step
		owner.get_tree().create_timer(delay, false).timeout.connect(_strike.bind(pos, fx, impact))
	if prm.has("heal"):
		owner.health.heal(roundi(owner.health.max_health * float(prm.heal)))
	_tfx().hit_stop(0.05)


## Une frappe venue du ciel (voir _a_storm).
func _strike(pos: Vector3, fx: String, impact: Callable) -> void:
	if not is_instance_valid(owner):
		return
	var big := data.category == "mystique"
	if fx == "blade":
		SkillFX.falling(owner, pos, data.color.lightened(0.3), "blade", 1.4 if big else 1.0, impact, 0.35)
	elif fx == "ice":
		SkillFX.falling(owner, pos, Color("bfeaff"), "spike", 1.2, impact, 0.35)
	else:
		var col: Color = {"fire": Color("ff7a2a"), "holy": Color("fff4c0"), "shadow": Color("2a1a3a"), "bolt": Color("fff27a")}.get(fx, data.color)
		SkillFX.pillar(owner, pos, col, 22.0 if big else 14.0, 0.9 if big else 0.6, 0.5)
		impact.call()


## Cataclysme : la compétence ultime. Après une seconde de silence, tout explose autour du héros : dégâts
## colossaux, ennemis projetés, et le sol se creuse en un cratère géant (arbres, rochers et constructions du
## monde volent en éclats ; les constructions du joueur sont épargnées).
func _a_crater(prm: Dictionary) -> void:
	var r := float(prm.get("radius", 24.0))
	var c := owner.global_position
	var dmg := _dmg(prm)
	_tfx().slow_motion(0.25, 1.6)
	SkillFX.pillar(owner, c, Color.WHITE, 80.0, 3.0, 2.0)
	SkillFX.screen_flash(owner, Color(1, 0.95, 0.8), 0.4, 0.35)
	owner.shake(1.5)
	owner._invulnerable_left = 3.0
	owner.get_tree().create_timer(0.9, false).timeout.connect(func():
		if not is_instance_valid(owner):
			return
		SkillFX.screen_flash(owner, Color(1, 0.85, 0.6), 1.4, 0.9)
		SkillFX.shockwave(owner, c, r * 1.3, Color("ffb050"), 6, 1.4)
		SkillFX.shockwave(owner, c, r, Color.WHITE, 3, 0.9)
		for k in 6:
			VoxelBurst.spawn(owner, c + Vector3(randf_range(-r, r) * 0.6, 0.5, randf_range(-r, r) * 0.6), [Color("8a6a4a"), Color("6a6a6a"), Color("ff9a3a")][k % 3], 90, r * 0.9, 0.22, 2.2, "sphere", 14.0, false)
		owner.shake(3.0)
		_tfx().hit_stop(0.12)
		Sound.ui("war_drums")
		for e in _enemies(c, r):
			_hit(e, dmg, 22.0, prm)
		carve_crater(c, r, float(prm.get("depth", 8.0))))


## Creuse un cratère en cuvette (plus profond au centre) et pulvérise ce qui s'y trouve.
func carve_crater(c: Vector3, r: float, depth: float) -> void:
	var world := owner.get_tree().get_first_node_in_group("world") as WorldGenerator
	if world == null or c.y < WorldGenerator.UNDERGROUND:
		return
	var center := world.cell_at(c)
	var cells := []
	var ri := ceili(r)
	var rim := ceili(r * 1.3)
	var floor_min := world.water_surface + 0.5
	for dz in range(-rim, rim + 1):
		for dx in range(-rim, rim + 1):
			var d := Vector2(dx, dz).length()
			if d > r * 1.3:
				continue
			var cell := center + Vector2i(dx, dz)
			var t := world.terrain_type(cell)
			if t == WorldGenerator.WATER or t == WorldGenerator.DEEP:
				continue
			var h := world.terrain_height(cell)
			var nh := h
			if d <= r:
				# la cuvette : plus profonde au centre, sans jamais descendre sous la mer (elle s'inonderait)
				var k := 1.0 - (d / r) * (d / r)
				nh = maxf(h - depth * k, minf(h, floor_min))
				# le rebord se relève vers le bord
				nh += depth * 0.55 * pow(d / r, 6.0)
			else:
				# la terre rejetée forme un bourrelet tout autour
				nh = h + depth * 0.55 * (1.0 - (d - r) / (r * 0.3))
			world.set_terrain_height(cell, nh)
			# le fond est de la roche brûlée
			if d < r * 0.85:
				world.set_terrain_type(cell, WorldGenerator.STONE)
			cells.append(cell)
	# les blocs du monde (ruines, maisons des hameaux...) volent en éclats, pas ceux du joueur
	if world.build:
		var gone := []
		for key in world.build.blocks:
			var kv: Vector3i = key
			if Vector2(kv.x - c.x, kv.z - c.z).length() <= r * 1.3 and not world.build.is_player_block(kv):
				gone.append(kv)
		for kv in gone:
			world.build.remove_block(kv)
	world.refresh_cells(cells)
	owner.global_position.y = world.ground_height_at(owner.global_position + Vector3(0, 30, 0))
