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
			_field_fx(f, center)
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


## Ce qui se voit dans une zone tant qu'elle dure (toutes les demi-secondes).
func _field_fx(f: Dictionary, center: Vector3) -> void:
	var r: float = f.radius
	var p := center + Vector3(randf_range(-r, r) * 0.6, 0.1, randf_range(-r, r) * 0.6)
	match str(f.get("fx", "")):
		"bubbles":
			VoxelBurst.emit(owner, p, {"palette": _pal(), "count": 8, "speed": 1.5, "size": 0.12, "life": 1.0, "mode": "column",
				"radius": r * 0.6, "hdr": 1.8, "gravity": -1.0, "grow": true})
		"snow":
			VoxelBurst.emit(owner, center + Vector3(0, 4.0, 0), {"palette": [Color.WHITE, Color("dff4ff"), data.color], "count": 14,
				"speed": 0.6, "size": 0.07, "life": 1.6, "mode": "column", "radius": r * 0.8, "hdr": 1.6, "gravity": 2.5, "drag": 3.0})
		"flames":
			VoxelBurst.emit(owner, center + Vector3(0, 0.1, 0), {"palette": _pal(), "count": 12, "speed": r * 1.2, "size": 0.1, "life": 0.5,
				"mode": "disc", "hdr": 2.2, "gravity": -3.0, "grow": true})


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
	_cast_flourish(kind)
	_cast_pose(kind)
	if data.category == "mystique":
		_mythic_intro(prm)
	call("_a_" + kind, prm)
	_cast_sound(kind, prm)
	cooldown_left = data.cooldown * SkillData.CD_SCALE[tier] * (1.0 - clampf(p("cdr_pct"), 0.0, 0.6))
	owner.visual.flash(Color(data.color, 0.4), 0.15)
	owner.feat.emit(("✦ " + current_name() + " ✦") if data.category == "mystique" else current_name() + " !", data.color.lightened(0.25))
	activated.emit()
	return true


# ---------------------------------------------------------------- sons

## Genre de magie d'une compétence (feu, glace, foudre, lumière, ombre, nature, arcane, arme) : d'après
## son effet, puis sa couleur.
static func genre_of(kind: String, prm: Dictionary, col: Color) -> String:
	var fx := str(prm.get("fx", ""))
	if kind in ["heal", "rally", "barrier"] or fx == "holy":
		return "holy"
	if kind in ["meteor", "crater"] or fx in ["fire", "flames"]:
		return "fire"
	if kind in ["chain", "storm"] or fx == "bolt":
		return "lightning"
	if kind == "slow_field" or fx in ["ice", "snow"]:
		return "ice"
	if kind in ["drain", "fear", "vortex"] or fx in ["shadow", "blood"]:
		return "shadow"
	if kind in ["dash", "execute", "move", "cone", "volley"] or fx in ["blade", "rocks"]:
		return "physical"
	if col.s < 0.25:
		return "physical"
	var h := col.h
	if h < 0.09 or h > 0.94:
		return "fire"
	if h < 0.18:
		return "holy"
	if h < 0.45:
		return "nature"
	if h < 0.66:
		return "ice"
	return "arcane"


## Le héros incante à la manière de sa classe (mage : mains levées puis projetées ; guerrier : arme
## brandie puis abattue ; clerc : bras ouverts vers le ciel ; rôdeur : arc bandé...). Les déplacements
## (ruée, clignement...) gardent leur propre mouvement.
func _cast_pose(kind: String) -> void:
	if kind in ["dash", "blink", "move", "execute"] or owner.visual == null or owner.in_move():
		return
	var cls: ClassData = owner.profile.hero_class if owner.profile else null
	var id := cls.resource_path.get_file().get_basename() if cls else ""
	owner.visual.play_move(MoveLibrary.cast_pose(id), 1.0)


## Le son du lancer : celui du genre ; les compétences légendaires et mystiques (les « ultimes »)
## rassemblent d'abord leur énergie puis éclatent dans une déflagration.
func _cast_sound(kind: String, prm: Dictionary) -> void:
	var at := owner.global_position + Vector3(0, 1, 0)
	Sound.play("cast_" + HeroSkill.genre_of(kind, prm, data.color), at, -1.0)
	if grade() >= 3:
		Sound.play("ult_charge", at, -2.0, 0.0)
		owner.get_tree().create_timer(0.45).timeout.connect(func():
			if is_instance_valid(owner):
				Sound.play("ult_boom", owner.global_position, 1.0 + (grade() - 3) * 2.0, 0.04))


# ---------------------------------------------------------------- ampleur des effets

## Ampleur des effets : 0 (commune) à 4 (mystique) selon la rareté du talent ; la compétence unique de
## l'histoire selon son rang (1 à 3). Plus c'est rare, plus c'est grand, lumineux et détaillé.
func grade() -> int:
	match data.category:
		"commune":
			return 0
		"rare":
			return 1
		"epique":
			return 2
		"legendaire":
			return 3
		"mystique":
			return 4
	return 1 + tier


## Facteur d'ampleur : 1 pour une compétence commune, jusqu'à ~2,4 pour une mystique.
func _k() -> float:
	return 1.0 + grade() * 0.35


func _pal() -> Array:
	return VoxelBurst.palette_of(data.color)


## Le geste du lanceur : un cercle de runes sous ses pieds, une gerbe qui monte de ses mains ;
## dès « légendaire », une colonne de lumière et un éclair d'écran.
func _cast_flourish(kind: String) -> void:
	var g := grade()
	var c := owner.global_position
	var hand := c + Vector3(0, 1.2, 0) + _forward() * 0.4
	if g >= 1 and kind not in ["dash", "blink", "execute", "move"]:
		SkillFX.runes(owner, c, 1.1 + 0.35 * g, data.color, 0.9 + 0.15 * g)
	VoxelBurst.emit(owner, hand, {"palette": _pal(), "count": 10 + 6 * g, "speed": 2.5, "size": 0.06, "life": 0.4,
		"hdr": 2.4, "gravity": -2.0, "streak": 1.2})
	SkillFX.flash_sphere(owner, hand, data.color, 0.35 + 0.08 * g, 0.18, 2.6)
	if g >= 3:
		SkillFX.pillar(owner, c, data.color.lightened(0.3), 10.0 + g * 3.0, 0.3, 0.4)
		SkillFX.screen_flash(owner, data.color.lightened(0.5), 0.25, 0.12)
		owner.shake(0.6)


# ---------------------------------------------------------------- outils

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
	VoxelBurst.emit(owner, pos + Vector3(0, 0.6, 0), {"palette": _pal(), "count": int(count * _k()), "speed": speed,
		"size": 0.1, "life": 0.6, "hdr": 2.0, "streak": 0.8})


## Petit éclat de la couleur de la compétence sur un ennemi touché.
func _mark(e: Combatant, big := false) -> void:
	SkillFX.impact(owner, e.global_position + Vector3(0, 1.0, 0), data.color, (e.global_position - owner.global_position) * Vector3(1, 0, 1), big, true)


# ---------------------------------------------------------------- compétences

## Nova : une explosion d'énergie autour du héros, des éclairs courent au sol jusqu'au bord.
func _a_nova(prm: Dictionary) -> void:
	var r := _radius(prm)
	var c := owner.global_position
	var g := grade()
	SkillFX.explosion(owner, c, data.color, r / 2.4 * (0.8 + 0.1 * g), g >= 2)
	SkillFX.ring(owner, c, r, data.color, 0.4)
	if g >= 1:
		SkillFX.shockwave(owner, c, r, data.color.lightened(0.2), 1 + mini(g, 3), 0.5)
	VoxelBurst.emit(owner, c + Vector3(0, 0.9, 0), {"palette": _pal(), "count": int(30 * _k()), "speed": r * 2.2, "size": 0.07,
		"life": 0.45, "mode": "disc", "hdr": 2.6, "gravity": 0.0, "drag": 2.0, "streak": 2.0})
	for i in (2 + g * 2):
		var a := TAU * i / (2 + g * 2) + randf() * 0.4
		SkillFX.lightning(owner, c + Vector3(0, 0.3, 0), c + Vector3(cos(a), 0.1, sin(a)) * r, data.color, 0.05, 0.25, 1)
	_tfx().hit_stop(0.06)
	owner.shake(1.0 + 0.2 * g)
	for e in _enemies(c, r):
		_hit(e, _dmg(prm), 7.0, prm)
	if prm.has("heal"):
		owner.health.heal(roundi(owner.health.max_health * float(prm["heal"])))
		VoxelBurst.emit(owner, c, {"color": Color(0.6, 1.0, 0.7), "count": 30, "speed": 3.0, "size": 0.08, "life": 0.9,
			"mode": "column", "radius": 0.6, "hdr": 2.2, "gravity": -1.0})
	# Fimbulvetr : un blizzard reste sur place
	if prm.has("field"):
		_a_slow_field({"radius": r * 0.6, "dps": 1.0, "factor": 0.3, "dur": 8})


## Salve : des projectiles lumineux à traînée, qui éclatent en touchant.
func _a_volley(prm: Dictionary) -> void:
	var n := data._count(tier)
	var spread := float(prm.get("spread", 0.6))
	var fwd := _forward()
	var g := grade()
	var col := data.color
	var muzzle := owner.global_position + Vector3(0, 1.1, 0) + fwd * 0.7
	SkillFX.flash_sphere(owner, muzzle, col, 0.5 + 0.1 * g, 0.16, 3.0)
	VoxelBurst.emit(owner, muzzle, {"palette": _pal(), "count": 14 + 4 * g, "speed": 6.0, "size": 0.05, "life": 0.3,
		"mode": "cone", "dir": fwd, "spread": 35.0, "streak": 2.0, "hdr": 2.6, "gravity": 2.0})
	for i in n:
		var bolt := MagicBolt.new()
		bolt.shooter = owner
		bolt.color = col
		var ang := (i - (n - 1) / 2.0) * (spread / maxf(1.0, n - 1.0)) if n > 1 else 0.0
		bolt.direction = fwd.rotated(Vector3.UP, ang)
		bolt.damage = roundi(_dmg(prm))
		bolt.range_left = 11.0
		bolt.speed = 15.0
		var extra := prm
		var big := g >= 2
		bolt.on_hit = func(t: Combatant):
			if is_instance_valid(t):
				SkillFX.explosion(owner, t.global_position + Vector3(0, 0.6, 0), col, 0.45 + 0.12 * g, false)
			if extra.has("burn") and randf() < float(extra["burn"]) + 0.3:
				t.apply_dot(maxf(2.0, _power() * 0.2), 3.0, owner, col)
			if extra.has("stun") and randf() < float(extra["stun"]):
				t.stagger(1.2, true)
		SkillFX._holder(owner).add_child(bolt)
		bolt.global_position = owner.global_position + Vector3(0, 1.1, 0) + bolt.direction * 0.7
		SkillFX.trail(bolt, col, 0.02 if big else 0.035, 0.09 + 0.02 * g, 2.6)


## Ruée : un trait de lumière sur tout le trajet, des images du héros, une entaille sur chaque ennemi traversé.
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
	_streak(start + Vector3(0, 1.0, 0), pos + Vector3(0, 1.0, 0), data.color, 0.12 + 0.03 * grade())
	VoxelBurst.emit(owner, start + Vector3(0, 0.2, 0), {"color": Color(0.7, 0.65, 0.55), "count": 12, "speed": 2.0, "size": 0.25,
		"life": 0.7, "mode": "ring", "glow": false, "grow": true, "alpha": 0.5, "gravity": -0.5})
	for e in owner.get_tree().get_nodes_in_group(owner.hostile_group()):
		var c := e as Combatant
		if c == null or not c.is_alive():
			continue
		var rel := c.global_position - start
		rel.y = 0.0
		var t := clampf(rel.dot(line) / maxf(line.length_squared(), 0.01), 0.0, 1.0)
		if (rel - line * t).length() < 1.3 + c.body_radius:
			_hit(c, _dmg(prm), 5.0, prm)
			SkillFX.slash(owner, c.global_position + Vector3(0, 1.0, 0), fwd, data.color, 1.2, 120.0, randf_range(-0.8, 0.8), 0.25, 0.5)
	_burst(pos, 20, 4.0)
	owner.shake(0.7)


## Un trait de lumière droit de `a` à `b` qui s'amincit et s'efface (ruée, téléportation).
func _streak(a: Vector3, b: Vector3, col: Color, width: float) -> void:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	var l := a.distance_to(b)
	if l < 0.1:
		return
	box.size = Vector3(width, width, l)
	mi.mesh = box
	var m := SkillFX.own_glow(Color(col.lightened(0.4), 1.0), 3.0, true)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	SkillFX._holder(owner).add_child(mi)
	mi.global_transform = Transform3D(Basis.looking_at(b - a, Vector3.UP), (a + b) * 0.5)
	var tw := mi.create_tween()
	tw.tween_property(mi, "scale", Vector3(0.05, 0.05, 1.0), 0.35).set_ease(Tween.EASE_IN)
	tw.tween_callback(mi.queue_free)
	for i in int(l * 3.0):
		var pt := a.lerp(b, randf())
		VoxelBurst.emit(owner, pt, {"palette": _pal(), "count": 2, "speed": 1.2, "size": 0.06, "life": 0.4, "hdr": 2.4, "gravity": -1.0})


## Soin : un cercle de runes, une colonne de lumières qui montent, et des filets de lumière vers les alliés.
func _a_heal(prm: Dictionary) -> void:
	var pct: float = float(prm.get("pct", 0.3)) * SkillData.HEAL_SCALE[tier]
	owner.health.heal(roundi(owner.health.max_health * pct))
	var c := owner.global_position
	var g := grade()
	SkillFX.runes(owner, c, 2.0 + 0.3 * g, data.color, 1.3)
	VoxelBurst.emit(owner, c + Vector3(0, 0.1, 0), {"palette": _pal(), "count": int(40 * _k()), "speed": 3.0, "size": 0.09,
		"life": 1.2, "mode": "column", "radius": 1.0, "hdr": 2.2, "gravity": -1.0, "drag": 1.0, "streak": 0.8})
	VoxelBurst.emit(owner, c + Vector3(0, 1.0, 0), {"palette": _pal(), "count": 20, "speed": 1.5, "size": 0.1, "life": 0.9,
		"mode": "shell", "radius": 0.9, "hdr": 2.0, "gravity": -2.0})
	SkillFX.flash_sphere(owner, c + Vector3(0, 1.0, 0), data.color, 1.2, 0.35, 2.0)
	SkillFX.light(owner, c + Vector3(0, 1.5, 0), data.color, 3.0, 6.0, 0.8)
	SkillFX.ring(owner, c, 2.5, data.color, 0.6)
	if prm.has("allies"):
		for v in owner.get_tree().get_nodes_in_group("villagers"):
			var cb := v as Combatant
			if cb and cb.global_position.distance_to(owner.global_position) < 9.0:
				if not cb.is_alive():
					cb.health.revive(pct)
					cb.visual.set_downed(false)
				else:
					cb.health.heal(roundi(cb.health.max_health * pct))
				SkillFX.stream(owner, c, cb, data.color, 8, 0.6)
				VoxelBurst.emit(owner, cb.global_position + Vector3(0, 0.2, 0), {"palette": _pal(), "count": 14, "speed": 2.0,
					"size": 0.08, "life": 0.8, "mode": "column", "radius": 0.5, "hdr": 2.2, "gravity": -2.0})


## Chant, bénédiction : renfort du héros, et les alliés proches (habitants, familiers) sont soignés.
func _a_rally(prm: Dictionary) -> void:
	_a_buff(prm)
	var pct := float(prm.get("heal", 0.1))
	SkillFX.ring(owner, owner.global_position, 9.0, data.color, 0.7)
	SkillFX.shockwave(owner, owner.global_position, 9.0, data.color.lightened(0.2), 2, 0.8)
	for g in ["villagers", "familiars"]:
		for n in owner.get_tree().get_nodes_in_group(g):
			var c := n as Combatant
			if c and c.is_alive() and c.global_position.distance_to(owner.global_position) < 9.0:
				c.health.heal(maxi(1, roundi(c.health.max_health * pct)))
				SkillFX.stream(owner, owner.global_position, c, data.color, 6, 0.5)
				VoxelBurst.emit(owner, c.global_position + Vector3(0, 0.2, 0), {"palette": _pal(), "count": 12, "speed": 2.0,
					"size": 0.08, "life": 0.8, "mode": "column", "radius": 0.4, "hdr": 2.2, "gravity": -2.0})


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
		e.power = 0.45 + 0.004 * owner.level + 0.002 * owner.magic_power()
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
		# la tombe s'ouvre : runes sombres, terre projetée, une flamme verdâtre qui monte
		SkillFX.runes(owner, pos, 0.9, data.color, 1.0)
		VoxelBurst.emit(owner, pos + Vector3(0, 0.1, 0), {"palette": [Color("5a4a3a"), Color("3a3028"), Color("7a6a50")], "count": 18,
			"speed": 4.0, "size": 0.12, "life": 0.8, "mode": "up", "glow": false, "gravity": 12.0})
		VoxelBurst.emit(owner, pos + Vector3(0, 0.1, 0), {"palette": _pal(), "count": 24, "speed": 2.5, "size": 0.1, "life": 1.0,
			"mode": "column", "radius": 0.4, "hdr": 2.4, "gravity": -1.0, "streak": 1.0})
		SkillFX.pillar(owner, pos, data.color, 4.0, 0.35, 0.6)


## Renfort : runes, une flamme de la couleur de la compétence qui enveloppe le héros, des cubes en orbite.
func _a_buff(prm: Dictionary) -> void:
	var dur := _dur(prm, 6.0)
	var s: float = SkillData.PASSIVE_SCALE[tier]
	for key in ["atk", "def", "spd", "aspd", "crit", "lifesteal", "burn"]:
		if prm.has(key):
			buffs[key] = [float(prm[key]) * (s if key != "def" else s), dur]
	if prm.has("cost"):
		owner.health.take_damage(maxi(1, roundi(owner.health.current * float(prm["cost"]))), owner)
	SkillFX.orbit(owner, data.color, dur, 0.8, 6 + grade() * 2)
	VoxelBurst.emit(owner, owner.global_position + Vector3(0, 0.1, 0), {"palette": _pal(), "count": int(40 * _k()), "speed": 4.5,
		"size": 0.08, "life": 0.7, "mode": "column", "radius": 0.7, "hdr": 2.4, "gravity": -1.0, "streak": 1.8})
	SkillFX.flash_sphere(owner, owner.global_position + Vector3(0, 1.0, 0), data.color, 1.1, 0.25, 2.4)
	SkillFX.ring(owner, owner.global_position, 2.0, data.color, 0.4)
	owner.refresh_stats()


## Barrière : une coque à facettes, un éclat et des étincelles qui jaillissent de sa surface.
func _a_barrier(prm: Dictionary) -> void:
	var dur := _dur(prm, 4.0)
	_barrier_left = dur
	_barrier_reduce = clampf(float(prm.get("reduce", 0.5)) + 0.05 * tier, 0.0, 1.0)
	_barrier_reflect = prm.has("reflect")
	SkillFX.shell(owner, data.color, dur, 1.1)
	var at := owner.global_position + Vector3(0, 0.9, 0)
	SkillFX.flash_sphere(owner, at, data.color, 1.3, 0.25, 2.6)
	VoxelBurst.emit(owner, at, {"palette": _pal(), "count": int(36 * _k()), "speed": 3.0, "size": 0.07, "life": 0.5,
		"mode": "shell", "radius": 1.1, "hdr": 2.4, "gravity": 0.0, "streak": 1.5})
	SkillFX.light(owner, at, data.color, 3.0, 4.0, 0.5)
	if prm.has("heal"):
		owner.health.heal(roundi(owner.health.max_health * float(prm["heal"])))


## Étourdissement : la terre se fend, une onde, et des étoiles tournent au-dessus des ennemis sonnés.
func _a_stun(prm: Dictionary) -> void:
	var r := _radius(prm, "radius", 4.0)
	var c := owner.global_position
	# Fureur de Gaïa : des pics de roche jaillissent partout
	if str(prm.get("fx", "")) == "rocks":
		for i in 26:
			var a := randf() * TAU
			var pos := c + Vector3(cos(a), 0, sin(a)) * randf_range(2.0, r)
			SkillFX.falling(owner, pos, Color("9a7a5a"), "spike", 1.3, func(): pass, 0.2 + i * 0.03)
	SkillFX.ring(owner, c, r, data.color, 0.5)
	SkillFX.shockwave(owner, c, r, data.color.lightened(0.2), 2, 0.5)
	VoxelBurst.emit(owner, c + Vector3(0, 0.1, 0), {"palette": [Color("8a7a60"), Color("6a5a48"), Color("aa9a80")], "count": int(30 * _k()),
		"speed": r * 1.6, "size": 0.14, "life": 0.6, "mode": "disc", "glow": false, "gravity": 6.0})
	_burst(c, 24, r * 1.5)
	owner.shake(0.9)
	var dur := _dur(prm, 2.0)
	for e in _enemies(c, r):
		if prm.has("dmg"):
			_hit(e, _dmg(prm), 2.0)
		if e.is_alive():
			e.stagger(dur, true)
			SkillFX.lightning(owner, c + Vector3(0, 1.0, 0), e.global_position + Vector3(0, 1.0, 0), data.color, 0.04, 0.22, 1)
			var stars := SkillFX.orbit(e, Color(1.0, 0.95, 0.5), dur, 0.45, 5)
			stars.position = Vector3(0, 2.0 * e.visual.scale.y, 0)


## Tourbillon : les particules sont aspirées en spirale vers le centre, puis tout explose.
func _a_vortex(prm: Dictionary) -> void:
	var r := _radius(prm, "radius", 5.0)
	var center := owner.global_position + _forward() * 2.5
	SkillFX.spiral(owner, center, r, data.color, 0.9)
	SkillFX.disc(owner, center, r, data.color, 1.0)
	SkillFX.runes(owner, center, r * 0.6, data.color, 1.0)
	for w in 2:
		VoxelBurst.emit(owner, center + Vector3(0, 0.8, 0), {"palette": _pal(), "count": int(40 * _k()), "speed": 5.0, "size": 0.08,
			"life": 0.8, "mode": "implode", "radius": r, "pull": 22.0, "hdr": 2.4, "gravity": 0.0, "drag": 1.5, "streak": 1.5})
	var victims := _enemies(center, r)
	for e in victims:
		var to: Vector3 = center - e.global_position
		to.y = 0.0
		e._knockback = to * 3.0
	var dmg := _dmg(prm)
	var g := grade()
	owner.get_tree().create_timer(0.75, false).timeout.connect(func():
		if not is_instance_valid(owner):
			return
		SkillFX.explosion(owner, center, data.color, r / 3.0 * (0.8 + 0.1 * g), g >= 2)
		SkillFX.ring(owner, center, r * 0.6, data.color, 0.35)
		owner.shake(1.0)
		for e in _enemies(center, r * 0.8):
			_hit(e, dmg, 3.0))


## Souffle en cône : un jet de flammes (ou de glace, de foudre...) en trois couches : traits de lumière,
## grosses flammèches qui gonflent, fumée.
func _a_cone(prm: Dictionary) -> void:
	var fwd := _forward()
	var rng := _radius(prm, "range", 5.0)
	var ang := float(prm.get("angle", 90.0))
	var o := owner.global_position + Vector3(0, 0.9, 0) + fwd * 0.5
	var spread := ang * 0.5
	VoxelBurst.emit(owner, o, {"palette": _pal(), "count": int(50 * _k()), "speed": rng * 2.4, "size": 0.07, "life": 0.42,
		"mode": "cone", "dir": fwd, "spread": spread, "hdr": 2.8, "gravity": 0.0, "drag": 1.0, "streak": 2.5})
	VoxelBurst.emit(owner, o, {"palette": _pal(), "count": int(36 * _k()), "speed": rng * 1.6, "size": 0.2, "life": 0.55,
		"mode": "cone", "dir": fwd, "spread": spread * 0.8, "hdr": 1.8, "gravity": -1.5, "drag": 2.0, "grow": true})
	VoxelBurst.emit(owner, o + fwd * rng * 0.5, {"color": Color(0.3, 0.28, 0.27), "count": 12, "speed": rng * 0.5, "size": 0.35,
		"life": 1.0, "mode": "cone", "dir": fwd, "spread": spread, "glow": false, "grow": true, "alpha": 0.4, "gravity": -1.0})
	SkillFX.flash_sphere(owner, o, data.color, 0.7, 0.2, 3.0)
	SkillFX.light(owner, o + fwd * rng * 0.4, data.color, 4.0, rng + 2.0, 0.5)
	owner.shake(0.7)
	for e in _enemies(owner.global_position, rng):
		var to: Vector3 = e.global_position - owner.global_position
		to.y = 0.0
		if to.length() < 0.5 or absf(rad_to_deg(Vector2(fwd.x, fwd.z).angle_to(Vector2(to.x, to.z)))) <= ang * 0.5:
			_hit(e, _dmg(prm), float(prm.get("kb", 6.0)), prm)


## Vol de vie : des filets de lumière partent des ennemis touchés et reviennent au héros.
func _a_drain(prm: Dictionary) -> void:
	var r := _radius(prm, "radius", 4.0)
	var total := 0
	var c := owner.global_position
	SkillFX.ring(owner, c, r, data.color, 0.5)
	SkillFX.runes(owner, c, r * 0.7, data.color, 1.0)
	for e in _enemies(c, r):
		var before: int = e.health.current
		_hit(e, _dmg(prm), 1.0)
		total += before - e.health.current
		SkillFX.stream(owner, e.global_position, owner, data.color, 10 + grade() * 2, 0.7)
		VoxelBurst.emit(owner, e.global_position + Vector3(0, 1.0, 0), {"palette": _pal(), "count": 14, "speed": 2.0, "size": 0.08,
			"life": 0.5, "mode": "implode", "radius": 0.8, "hdr": 2.4, "gravity": 0.0})
	if total > 0:
		owner.health.heal(maxi(1, roundi(total * float(prm.get("ratio", 0.5)))))
		owner.get_tree().create_timer(0.6, false).timeout.connect(func():
			if is_instance_valid(owner):
				SkillFX.flash_sphere(owner, owner.global_position + Vector3(0, 1.0, 0), data.color, 1.0, 0.25, 2.4)
				VoxelBurst.emit(owner, owner.global_position + Vector3(0, 0.3, 0), {"palette": _pal(), "count": 24, "speed": 2.0,
					"size": 0.09, "life": 0.8, "mode": "column", "radius": 0.6, "hdr": 2.2, "gravity": -2.0}))


## Météores : un cercle de runes marque chaque point d'impact, la boule de feu tombe en traînant
## flammes et fumée, puis explose (boule de feu, débris, fumée, brûlure au sol).
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
	var g := grade()
	for i in n:
		var pos: Vector3 = targets[i]
		var delay := 0.55 + i * 0.18
		SkillFX.runes(owner, pos, r * 0.8, data.color, delay + 0.2)
		SkillFX.meteor(owner, pos, data.color, 0.5 + r * 0.12 + 0.08 * g, func():
			if not is_instance_valid(owner):
				return
			SkillFX.explosion(owner, pos, data.color, r / 2.2 * (0.9 + 0.1 * g), true)
			_tfx().hit_stop(0.05)
			owner.shake(1.2 + 0.2 * g)
			for e in _enemies(pos, r):
				_hit(e, dmg, 8.0, prm), delay)


## Zone de dégâts continus (poison, flammes) : runes, disque et bulles qui montent tant qu'elle dure.
func _a_dot(prm: Dictionary) -> void:
	var r := _radius(prm, "radius", 4.0)
	var dur := _dur(prm, 5.0)
	SkillFX.disc(owner, owner.global_position, r, data.color, dur)
	SkillFX.runes(owner, owner.global_position, r, data.color, dur)
	_burst(owner.global_position, 30, 3.0)
	_fields.append({"pos": owner.global_position, "radius": r, "dur": dur, "dps": _dmg({"dmg": float(prm.get("dps", 0.3)) * 2.0}), "slow": 0.0, "follow": false, "tick": 0.0, "fx": "bubbles"})


## Zone de froid : runes, givre au sol et flocons qui tombent tant qu'elle dure.
func _a_slow_field(prm: Dictionary) -> void:
	var r := _radius(prm, "radius", 5.0)
	var dur := _dur(prm, 5.0)
	SkillFX.disc(owner, owner.global_position, r, data.color, dur)
	SkillFX.ring(owner, owner.global_position, r, data.color, 0.6)
	SkillFX.runes(owner, owner.global_position, r, data.color, dur)
	var dps := _dmg({"dmg": float(prm.get("dps", 0.0)) * 2.0}) if prm.has("dps") else 0.0
	_fields.append({"pos": owner.global_position, "radius": r, "dur": dur, "dps": dps, "slow": float(prm.get("factor", 0.4)), "follow": false, "tick": 0.0, "fx": "snow"})


## Aura : des cubes en orbite et des flammes qui lèchent le sol autour du héros tant qu'elle dure.
func _a_aura(prm: Dictionary) -> void:
	var r := _radius(prm, "radius", 2.5)
	var dur := _dur(prm, 5.0)
	SkillFX.orbit(owner, data.color, dur, r * 0.8, 10 + grade() * 2)
	SkillFX.runes(owner, owner.global_position, r, data.color, dur, owner)
	_fields.append({"pos": owner.global_position, "radius": r, "dur": dur, "dps": _dmg({"dmg": float(prm.get("dps", 0.4)) * 2.0}), "slow": 0.0, "follow": true, "tick": 0.0, "fx": "flames"})


## Effroi : une vague d'ombre, des fumerolles sombres sur les ennemis qui fuient.
func _a_fear(prm: Dictionary) -> void:
	var r := _radius(prm, "radius", 6.0)
	var c := owner.global_position
	var dark := data.color.darkened(0.3)
	SkillFX.ring(owner, c, r, dark, 0.6)
	SkillFX.shockwave(owner, c, r, dark, 2, 0.7)
	VoxelBurst.emit(owner, c + Vector3(0, 0.4, 0), {"palette": [Color(0.08, 0.05, 0.1), Color(0.2, 0.1, 0.25), dark], "count": int(30 * _k()),
		"speed": r * 1.4, "size": 0.3, "life": 0.9, "mode": "disc", "glow": false, "grow": true, "alpha": 0.6, "gravity": -0.5})
	VoxelBurst.emit(owner, c + Vector3(0, 1.0, 0), {"palette": _pal(), "count": 24, "speed": 4.0, "size": 0.07, "life": 0.6,
		"hdr": 2.2, "streak": 1.5, "gravity": 0.0})
	owner.shake(0.8)
	for e in _enemies(c, r):
		if prm.has("dmg"):
			_hit(e, _dmg(prm), 3.0)
		if e.is_alive() and e.has_method("frighten"):
			e.frighten(_dur(prm, 3.0))
			VoxelBurst.emit(owner, e.global_position + Vector3(0, 1.6, 0), {"color": Color(0.12, 0.08, 0.16), "count": 8, "speed": 1.0,
				"size": 0.22, "life": 1.0, "mode": "up", "glow": false, "grow": true, "alpha": 0.6, "gravity": -1.5})


## Exécution : le héros apparaît derrière sa cible et la tranche en croix ; une exécution réussie
## (cible affaiblie) ajoute une explosion, une étoile et un temps d'arrêt plus long.
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
	var from := owner.global_position
	owner.visual.spawn_afterimage(Color(data.color, 0.5), 0.4)
	owner.global_position = target.global_position - to.normalized() * (target.body_radius + 0.9)
	owner.facing = to.normalized()
	owner.visual.rotation.y = atan2(to.x, to.z)
	_streak(from + Vector3(0, 1.0, 0), owner.global_position + Vector3(0, 1.0, 0), data.color, 0.1)
	var dmg := _dmg(prm)
	var at := target.global_position + Vector3(0, 1.0, 0)
	var killing := target.health.ratio() <= float(prm.get("threshold", 0.3))
	if killing:
		dmg *= 3.0
		Combat.popup(target, target.global_position + Vector3(0, 2.3, 0), "Exécution !", data.color.lightened(0.3), true)
	owner.perform("counter", 1.3, 0.0)
	_hit(target, dmg, 6.0)
	SkillFX.slash(owner, at, to, data.color, 1.5, 150.0, 0.8, 0.3, 0.6)
	SkillFX.slash(owner, at, to, data.color, 1.5, 150.0, -0.8, 0.3, 0.6)
	if killing:
		SkillFX.explosion(owner, target.global_position, data.color, 0.9, false)
		SkillFX.star(owner, at, data.color, 2.5, 0.35)
		SkillFX.screen_flash(owner, data.color.lightened(0.4), 0.25, 0.2)
		_tfx().hit_stop(0.16)
	else:
		VoxelBurst.emit(owner, at, {"palette": _pal(), "count": 30, "speed": 6.0, "size": 0.06, "life": 0.4, "hdr": 2.6, "streak": 2.0})
		_tfx().hit_stop(0.1)
	owner.shake(1.3)


## Attaque du répertoire de mouvements (tourbillon...) avec un bonus de dégâts.
func _a_move(prm: Dictionary) -> void:
	owner._do_move(str(prm.get("move", "spin")), 1.0, float(prm.get("dmg", 1.0)) * SkillData.DMG_SCALE[tier])
	SkillFX.ring(owner, owner.global_position, 2.6, data.color, 0.35)
	VoxelBurst.emit(owner, owner.global_position + Vector3(0, 0.9, 0), {"palette": _pal(), "count": int(24 * _k()), "speed": 5.0,
		"size": 0.06, "life": 0.4, "mode": "disc", "hdr": 2.4, "gravity": 0.0, "streak": 2.0})
	owner.visual.set_trail(true, data.color)
	owner.get_tree().create_timer(0.6, false).timeout.connect(func():
		if is_instance_valid(owner):
			owner.visual.set_trail(false))


## Éclair en chaîne : de vrais éclairs zigzag qui frappent l'ennemi le plus proche puis rebondissent.
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
		SkillFX.lightning(owner, from, to, data.color, 0.06 + 0.01 * grade(), 0.3, 2 + grade())
		_hit(cur, _dmg(prm) * (1.0 - 0.12 * i), 3.0, prm)
		_mark(cur, i == 0)
		hit.append(cur)
		from = to
		cur = null
	if not hit.is_empty():
		_tfx().hit_stop(0.04)
		owner.shake(0.5)


## Transfert : le héros est aspiré dans un point de lumière et réapparaît dans un éclat.
func _a_blink(prm: Dictionary) -> void:
	var fwd := _forward()
	var dist := _radius(prm, "dist", 6.0)
	var world := owner.get_tree().get_first_node_in_group("world") as WorldGenerator
	var pos := owner.global_position
	var start := pos
	owner.visual.spawn_afterimage(Color(data.color, 0.6), 0.5)
	VoxelBurst.emit(owner, pos + Vector3(0, 0.9, 0), {"palette": _pal(), "count": 26, "speed": 3.0, "size": 0.07, "life": 0.4,
		"mode": "implode", "radius": 1.2, "pull": 25.0, "hdr": 2.6, "gravity": 0.0, "streak": 1.5})
	for s in int(dist / 0.25):
		var nxt := pos + fwd * 0.25
		if world:
			nxt = world.constrain_move(pos, nxt)
		if nxt.distance_to(pos) < 0.05:
			break
		pos = nxt
	owner.global_position = pos
	owner._invulnerable_left = 0.4
	_streak(start + Vector3(0, 0.9, 0), pos + Vector3(0, 0.9, 0), data.color, 0.06)
	SkillFX.flash_sphere(owner, pos + Vector3(0, 0.9, 0), data.color, 0.9, 0.2, 3.0)
	VoxelBurst.emit(owner, pos + Vector3(0, 0.9, 0), {"palette": _pal(), "count": 26, "speed": 4.5, "size": 0.06, "life": 0.4,
		"hdr": 2.6, "streak": 2.0, "gravity": 0.0})
	if prm.has("dmg"):
		SkillFX.ring(owner, pos, 2.5, data.color, 0.35)
		for e in _enemies(pos, 2.5):
			_hit(e, _dmg(prm), 5.0)


# ---------------------------------------------------------------- mystiques

## Mise en scène des compétences mystiques : le temps ralentit, l'énergie est aspirée vers le héros,
## un immense cercle de runes s'ouvre, huit colonnes de lumière s'élèvent en couronne, puis la colonne
## centrale jaillit, l'écran s'illumine, des ondes de choc se succèdent et la terre tremble.
func _mythic_intro(prm: Dictionary) -> void:
	var c := owner.global_position
	var r := float(prm.get("radius", prm.get("area", 12.0)))
	_tfx().slow_motion(0.35, 1.1)
	SkillFX.runes(owner, c, minf(r * 0.6, 9.0), data.color, 2.0)
	VoxelBurst.emit(owner, c + Vector3(0, 1.0, 0), {"palette": _pal(), "count": 90, "speed": 6.0, "size": 0.08, "life": 0.9,
		"mode": "implode", "radius": minf(r * 0.7, 10.0), "pull": 30.0, "hdr": 2.8, "gravity": 0.0, "streak": 2.0})
	for i in 8:
		var a := TAU * i / 8.0
		var p := c + Vector3(cos(a), 0, sin(a)) * minf(r * 0.55, 8.0)
		owner.get_tree().create_timer(0.04 * i, false).timeout.connect(func():
			if is_instance_valid(owner):
				SkillFX.pillar(owner, p, data.color.lightened(0.2), 18.0, 0.35, 0.9))
	SkillFX.pillar(owner, c, data.color.lightened(0.3), 40.0, 1.6, 1.4)
	SkillFX.screen_flash(owner, data.color.lightened(0.5), 0.7, 0.5)
	SkillFX.shockwave(owner, c, r, data.color, 4, 0.9)
	VoxelBurst.emit(owner, c + Vector3(0, 0.4, 0), {"palette": _pal(), "count": 140, "speed": 9.0, "size": 0.12, "life": 1.6,
		"mode": "up", "hdr": 2.6, "gravity": -1.0, "streak": 1.5})
	VoxelBurst.emit(owner, c + Vector3(0, 0.2, 0), {"palette": _pal(), "count": 90, "speed": r * 0.9, "size": 0.12, "life": 1.0,
		"mode": "ring", "hdr": 2.2, "gravity": 0.0, "streak": 1.2})
	SkillFX.light(owner, c + Vector3(0, 3.0, 0), data.color, 8.0, r + 6.0, 1.4)
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
	var g := grade()
	for i in points.size():
		var pos: Vector3 = points[i]
		var world := owner.get_tree().get_first_node_in_group("world") as WorldGenerator
		if world and pos.y > WorldGenerator.UNDERGROUND:
			pos.y = world.support_height(pos, world.terrain_height(world.cell_at(pos)) + 0.4)
		var col := _storm_color(fx)
		var impact := func():
			if not is_instance_valid(owner):
				return
			SkillFX.explosion(owner, pos, col, hit_r / 2.4 * (0.8 + 0.1 * g), i % 2 == 0)
			for e in _enemies(pos, hit_r):
				_hit(e, dmg, float(prm.get("kb", 6.0)), prm)
				if prm.has("fear") and e.is_alive() and e.has_method("frighten"):
					e.frighten(float(prm.fear))
			owner.shake(0.6)
		var delay := 0.25 + i * step
		SkillFX.runes(owner, pos, hit_r * 0.7, col, delay + 0.2)
		owner.get_tree().create_timer(delay, false).timeout.connect(_strike.bind(pos, fx, impact))
	if prm.has("heal"):
		owner.health.heal(roundi(owner.health.max_health * float(prm.heal)))
	_tfx().hit_stop(0.05)


func _storm_color(fx: String) -> Color:
	return {"fire": Color("ff7a2a"), "holy": Color("fff4c0"), "shadow": Color("7a3aaa"), "bolt": Color("fff27a"),
		"ice": Color("bfeaff")}.get(fx, data.color)


## Une frappe venue du ciel (voir _a_storm) : la foudre tombe vraiment en zigzag ; feu, lumière et ombre
## tombent en colonnes ; lames et pics de glace tombent du ciel.
func _strike(pos: Vector3, fx: String, impact: Callable) -> void:
	if not is_instance_valid(owner):
		return
	var big := data.category == "mystique"
	var col := _storm_color(fx)
	if fx == "blade":
		SkillFX.falling(owner, pos, data.color.lightened(0.3), "blade", 1.4 if big else 1.0, impact, 0.35)
	elif fx == "ice":
		SkillFX.falling(owner, pos, col, "spike", 1.2, impact, 0.35)
	elif fx == "bolt":
		SkillFX.lightning(owner, pos + Vector3(randf_range(-2, 2), 22.0, randf_range(-2, 2)), pos + Vector3(0, 0.2, 0), col,
			0.14 if big else 0.1, 0.35, 4)
		impact.call()
	else:
		SkillFX.pillar(owner, pos, col, 22.0 if big else 14.0, 0.9 if big else 0.6, 0.5)
		if fx == "shadow":
			VoxelBurst.emit(owner, pos + Vector3(0, 1.0, 0), {"palette": [Color(0.1, 0.05, 0.15), Color(0.3, 0.12, 0.4)], "count": 20,
				"speed": 3.0, "size": 0.2, "life": 0.6, "mode": "implode", "radius": 2.0, "glow": false, "grow": true, "alpha": 0.7})
		impact.call()


## Cataclysme : la compétence ultime. Pendant une seconde, tout le décor est aspiré vers le héros dans un
## silence de lumière ; puis tout explose autour de lui : une couronne d'explosions, des ondes de choc,
## dégâts colossaux, ennemis projetés, et le sol se creuse en un cratère géant (arbres, rochers et
## constructions du monde volent en éclats ; les constructions du joueur sont épargnées).
func _a_crater(prm: Dictionary) -> void:
	var r := float(prm.get("radius", 24.0))
	var c := owner.global_position
	var dmg := _dmg(prm)
	_tfx().slow_motion(0.25, 1.6)
	SkillFX.pillar(owner, c, Color.WHITE, 80.0, 3.0, 2.0)
	SkillFX.runes(owner, c, minf(r * 0.5, 14.0), Color(1.0, 0.8, 0.5), 1.4)
	SkillFX.screen_flash(owner, Color(1, 0.95, 0.8), 0.4, 0.35)
	for w in 3:
		VoxelBurst.emit(owner, c + Vector3(0, 1.0, 0), {"palette": [Color.WHITE, Color("ffd9a0"), Color("ffb050"), Color("ff7a2a")],
			"count": 80, "speed": 8.0, "size": 0.1, "life": 0.9, "mode": "implode", "radius": minf(r * 0.8, 18.0), "pull": 40.0,
			"hdr": 3.0, "gravity": 0.0, "streak": 2.5})
	SkillFX.light(owner, c + Vector3(0, 4.0, 0), Color(1.0, 0.85, 0.6), 10.0, r, 1.0)
	owner.shake(1.5)
	owner._invulnerable_left = 3.0
	owner.get_tree().create_timer(0.9, false).timeout.connect(func():
		if not is_instance_valid(owner):
			return
		SkillFX.screen_flash(owner, Color(1, 0.85, 0.6), 1.0, 0.6)
		SkillFX.shockwave(owner, c, r * 1.3, Color("ffb050"), 6, 1.4)
		SkillFX.shockwave(owner, c, r, Color.WHITE, 3, 0.9)
		SkillFX.explosion(owner, c, Color("ffb050"), 4.0, true)
		SkillFX.flash_sphere(owner, c + Vector3(0, 1.0, 0), Color(1, 0.9, 0.7), minf(r * 0.3, 7.0), 0.6, 3.0)
		# une couronne d'explosions qui s'éloigne du centre
		for k in 12:
			var a := TAU * k / 12.0 + randf() * 0.3
			var d := r * randf_range(0.35, 0.9)
			var p := c + Vector3(cos(a), 0, sin(a)) * d
			owner.get_tree().create_timer(0.05 + d / r * 0.4, false).timeout.connect(func():
				if is_instance_valid(owner):
					SkillFX.explosion(owner, p, [Color("ffb050"), Color("ff7a2a"), Color("fff0c0")][k % 3], 2.0, k % 2 == 0))
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
