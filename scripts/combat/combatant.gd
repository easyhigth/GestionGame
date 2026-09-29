class_name Combatant
extends CharacterBody3D
## Base commune du joueur, des habitants et des monstres : vie, coups (animations de MoveLibrary),
## garde et parade, équilibre (un combattant déséquilibré est étourdi), recul.
## Chaque combattant a un nœud « Health » et un nœud « Visual » (VoxelCharacter).

signal hurt(amount: int, source: Node)
signal defeated
signal parried(attacker: Combatant)
signal move_finished(move_name: String)

## Camp : les alliés (joueur, habitants) ou les ennemis (monstres).
enum Team { ALLIES, ENEMIES }

@export var team: Team = Team.ALLIES
## Rayon du corps (pour savoir si un coup touche).
@export var body_radius: float = 0.35
## Portée des coups à mains nues.
@export var unarmed_reach: float = 1.3
## Temps d'invulnérabilité après avoir été touché (secondes).
@export var hit_invulnerability: float = 0.3
## Équilibre : quand il tombe à 0, le combattant est étourdi. Sous 20, chaque coup le fait tressaillir.
@export var poise_max: float = 40.0
## Angle protégé par la garde (degrés, devant soi).
@export var block_arc: float = 150.0
## Une garde levée juste avant le coup (moins de ce temps) est une PARADE.
@export var parry_window: float = 0.22

@onready var visual: VoxelCharacter = $Visual
@onready var health: Health = $Health

var equipment: CharacterEquipment
## Direction regardée.
var facing: Vector3 = Vector3.BACK
## Garde levée.
var blocking := false
var poise := 40.0

var _knockback := Vector3.ZERO
var _attack_cooldown := 0.0
var _invulnerable_left := 0.0
var _world: WorldGenerator
var _hit_pending := -1.0

# coup en cours
var move_name := ""
var move_t := 0.0
var move_speed := 1.0
var _move := {}
var _hits_done := 0
var _move_damage := 1.0

# garde, équilibre, étourdissement
var _block_time := 0.0
var _stagger_left := 0.0
var _flinch_left := 0.0
var _poise_timer := 0.0


func _ready() -> void:
	equipment = get_node_or_null("Equipment") as CharacterEquipment
	poise = poise_max
	add_to_group("combatants")
	add_to_group("allies" if team == Team.ALLIES else "enemies")
	health.died.connect(_on_died)
	var bar := get_node_or_null("HealthBar") as HealthBar3D
	if bar:
		health.changed.connect(func(c, m): bar.set_ratio(float(c) / float(maxi(m, 1))))


# ---------------------------------------------------------------- caractéristiques (à redéfinir)

func base_attack() -> int:
	return 10


func base_defense() -> int:
	return 0


func base_magic() -> int:
	return 10


func attack_power() -> int:
	var bonus := equipment.total_attack() if equipment else 0
	if weapon() == null:
		return maxi(1, roundi(base_attack() * 0.6) + bonus)
	return base_attack() + bonus


func defense_power() -> int:
	return base_defense() + (equipment.total_defense() if equipment else 0)


func magic_power() -> int:
	return base_magic() + (equipment.total_magic() if equipment else 0)


func weapon() -> ItemData:
	return equipment.get_item(ItemData.Slot.MAIN_HAND) if equipment else null


func has_shield() -> bool:
	return equipment != null and equipment.get_item(ItemData.Slot.OFF_HAND) != null


func weapon_style() -> int:
	var w := weapon()
	return w.weapon_style if w else ItemData.WeaponStyle.UNARMED


func attack_reach() -> float:
	var w := weapon()
	return w.reach if w else unarmed_reach


## Vitesse des coups (1 = normale).
func attack_speed() -> float:
	var w := weapon()
	return w.attack_speed if w else 1.2


func knockback_strength() -> float:
	var w := weapon()
	return 3.0 + (w.knockback if w else 0.0)


func hostile_group() -> String:
	return "enemies" if team == Team.ALLIES else "allies"


func is_alive() -> bool:
	return health != null and not health.is_dead()


func is_invulnerable() -> bool:
	return _invulnerable_left > 0.0


func is_staggered() -> bool:
	return _stagger_left > 0.0


func is_dizzy() -> bool:
	return _stagger_left > 0.0 and visual.current_move() == "dizzy"


func can_act() -> bool:
	return is_alive() and _stagger_left <= 0.0 and _flinch_left <= 0.0


func is_attacking() -> bool:
	return not _move.is_empty() or visual.is_attacking() or _hit_pending > 0.0


func can_attack() -> bool:
	return can_act() and _attack_cooldown <= 0.0 and _move.is_empty()


# ---------------------------------------------------------------- coups

## Lance un coup de MoveLibrary. `damage` multiplie les dégâts du coup.
func perform(name: String, speed := 1.0, damage := 1.0) -> bool:
	if not can_act():
		return false
	var m := MoveLibrary.get_move(name)
	if m.is_empty():
		return false
	if not _move.is_empty():
		_end_move(true)
	_move = m
	move_name = name
	move_t = 0.0
	move_speed = speed
	_hits_done = 0
	_move_damage = damage
	blocking = false
	visual.play_move(name, speed)
	_on_move_started(name)
	return true


func in_move() -> bool:
	return not _move.is_empty()


## Vrai quand le coup en cours peut s'enchaîner avec le suivant.
func can_chain() -> bool:
	return in_move() and move_t >= float(_move.get("combo", _move["duration"]))


## Vrai quand le coup en cours peut être annulé (par une roulade).
func can_cancel() -> bool:
	return not in_move() or move_t >= float(_move.get("cancel", _move["duration"]))


func cancel_move() -> void:
	if in_move():
		_end_move(true)
	visual.stop_move()


func _end_move(interrupted: bool) -> void:
	var n := move_name
	_move = {}
	move_name = ""
	if not interrupted:
		move_finished.emit(n)
	_on_move_ended(n, interrupted)


func _update_move(delta: float) -> void:
	if _move.is_empty():
		return
	move_t += delta * move_speed
	var hits: Array = _move.get("hits", [])
	while not _move.is_empty() and _hits_done < hits.size() and float(hits[_hits_done]["t"]) <= move_t:
		var h: Dictionary = hits[_hits_done]
		_hits_done += 1
		_do_hit(h)
	# le coup a pu être interrompu (parade, étourdissement)
	if _move.is_empty():
		return
	if move_t >= float(_move["duration"]) and not _move.get("hold", false):
		_end_move(false)


## Vitesse d'élan pendant un coup (le personnage avance en frappant).
func lunge_velocity() -> Vector3:
	if _move.is_empty() or not _move.has("lunge"):
		return Vector3.ZERO
	var l: Array = _move["lunge"]
	if move_t < l[0] or move_t > l[1]:
		return Vector3.ZERO
	return Vector3(facing.x, 0, facing.z).normalized() * (float(l[2]) / maxf(float(l[1]) - float(l[0]), 0.01)) * move_speed


func _do_hit(h: Dictionary) -> void:
	if h.get("cast", false):
		_cast(h)
		return
	var reach := attack_reach() * float(h.get("reach", 1.0))
	var arc := 360.0 if h.get("around", false) else float(h.get("arc", 120.0))
	var atk := roundi(attack_power() * float(h.get("dmg", 1.0)) * _move_damage)
	var n := Combat.melee(self, reach, arc, atk, knockback_strength() * float(h.get("kb", 1.0)), float(h.get("poise", 1.0)) * _move_damage)
	if h.get("shock", false):
		var front := global_position + Vector3(facing.x, 0, facing.z).normalized() * minf(reach * 0.6, 1.4) + Vector3(0, 0.1, 0)
		VoxelBurst.spawn(self, front, Color(0.95, 0.9, 0.75), 26, 5.5, 0.12, 0.45, "ring", 2.0, false)
		VoxelBurst.spawn(self, front, Color(1.0, 0.95, 0.8), 10, 3.0, 0.08, 0.35, "up", 6.0)
	_on_attack_landed(n, h)


func _cast(h: Dictionary) -> void:
	var w := weapon()
	var count := int(h.get("spread", 1))
	for i in count:
		var bolt := MagicBolt.new()
		bolt.shooter = self
		var ang := (i - (count - 1) / 2.0) * 0.28
		bolt.direction = Vector3(facing.x, 0, facing.z).normalized().rotated(Vector3.UP, ang)
		bolt.damage = roundi(magic_power() * float(h.get("dmg", 1.0)) * _move_damage)
		bolt.range_left = w.reach if w else 8.0
		var holder: Node = get_tree().current_scene if get_tree().current_scene else get_tree().root
		holder.add_child(bolt)
		bolt.global_position = global_position + Vector3(0, 1.1, 0) + bolt.direction * 0.7


## Appelé après chaque coup porté (nombre de cibles touchées).
func _on_attack_landed(_hits: int, _hit: Dictionary) -> void:
	pass


func _on_move_started(_name: String) -> void:
	pass


func _on_move_ended(_name: String, _interrupted: bool) -> void:
	pass


# ---------------------------------------------------------------- garde

## Lève ou baisse la garde (bouclier devant soi).
func set_blocking(on: bool) -> void:
	if on == blocking:
		return
	blocking = on
	if on:
		_block_time = 0.0
		visual.play_move("block" if has_shield() else "block_bare")
	elif visual.current_move().begins_with("block"):
		visual.stop_move()


func _is_in_front(source: Node3D) -> bool:
	if source == null:
		return false
	var off := Vector2(source.global_position.x - global_position.x, source.global_position.z - global_position.z)
	if off.length() < 0.05:
		return true
	return absf(rad_to_deg(Vector2(facing.x, facing.z).angle_to(off))) <= block_arc * 0.5


# ---------------------------------------------------------------- dégâts reçus

## Reçoit un coup de puissance `attack`. Renvoie vrai si le coup a porté.
func receive_hit(attack: int, source: Node3D, knockback := 3.0, poise_damage := 1.0) -> bool:
	if not is_alive():
		return false
	var attacker := _attacker_of(source)
	if is_invulnerable():
		_on_evaded(attacker)
		return false
	if blocking and _is_in_front(source):
		if _block_time <= parry_window:
			_on_parry(attacker)
			return false
		_on_blocked(attack, source, knockback)
		return false
	# bonus de l'attaquant (critique, rage, exécution...)
	var crit := false
	if attacker:
		crit = attacker.roll_crit()
		var mult := attacker.outgoing_multiplier(self) * (attacker.crit_multiplier() if crit else 1.0)
		attack = roundi(attack * mult)
	var dmg := Combat.compute_damage(attack, defense_power())
	if is_dizzy():
		dmg = roundi(dmg * 1.5)
	dmg = maxi(0, roundi(dmg * incoming_multiplier()))
	health.take_damage(dmg, source)
	_invulnerable_left = hit_invulnerability
	visual.flash()
	var color := Color("ffe070") if team == Team.ENEMIES else Color("ff5a4a")
	if crit:
		color = Color("ff9a2a")
	var top := global_position + Vector3(0, 1.9 * visual.scale.y, 0)
	Combat.popup(self, top, str(dmg) + ("!" if crit else ""), color, dmg >= 15 or crit)
	if attacker:
		attacker._on_damage_dealt(self, dmg)
	VoxelBurst.spawn(self, global_position + Vector3(0, 1.0 * visual.scale.y, 0), Color(1.0, 0.95, 0.7), 10, 4.5, 0.07, 0.3)
	if source:
		var away := global_position - source.global_position
		away.y = 0.0
		if away.length_squared() > 0.0001:
			_knockback = away.normalized() * knockback
	hurt.emit(dmg, source)
	_on_hurt(dmg, source)
	# équilibre
	if is_alive():
		_poise_timer = 3.0
		if _stagger_left <= 0.0:
			poise -= dmg * poise_damage * (attacker.poise_multiplier() if attacker else 1.0)
			if poise <= 0.0:
				break_poise()
			elif poise_max < 20.0:
				flinch()
	return true


func _attacker_of(source: Node) -> Combatant:
	if source is Combatant:
		return source
	if source is MagicBolt:
		return (source as MagicBolt).shooter
	return null


## Un coup vient de passer tout près (utilisé pour l'esquive parfaite du joueur).
func notify_near_miss(attacker: Combatant) -> void:
	if is_invulnerable():
		_on_evaded(attacker)


func _on_evaded(_attacker: Combatant) -> void:
	pass


func _on_blocked(attack: int, source: Node3D, knockback: float) -> void:
	# garde : le bouclier encaisse presque tout, sans bouclier on prend la moitié
	var dmg := 0 if has_shield() else roundi(Combat.compute_damage(attack, defense_power()) * 0.5)
	if dmg > 0:
		health.take_damage(dmg, source)
	var away := global_position - source.global_position
	away.y = 0.0
	_knockback = away.normalized() * knockback * 0.6
	var spark_pos := global_position + Vector3(facing.x, 0, facing.z).normalized() * 0.45 + Vector3(0, 1.0, 0)
	VoxelBurst.spawn(self, spark_pos, Color(1.0, 0.85, 0.4), 14, 5.0, 0.06, 0.25)
	Combat.popup(self, global_position + Vector3(0, 2.0, 0), "Bloqué" if dmg == 0 else str(dmg), Color("c8d8ff"))
	visual.flash(Color(0.8, 0.9, 1.0, 0.4), 0.08)


## Parade réussie : l'attaquant est déséquilibré, on peut contre-attaquer.
func _on_parry(attacker: Combatant) -> void:
	var pos := global_position + Vector3(facing.x, 0, facing.z).normalized() * 0.5 + Vector3(0, 1.1, 0)
	VoxelBurst.spawn(self, pos, Color(1.0, 1.0, 0.85), 30, 7.0, 0.08, 0.35)
	VoxelBurst.spawn(self, pos, Color(1.0, 0.8, 0.3), 18, 3.5, 0.12, 0.45, "ring", 0.0)
	blocking = false
	visual.play_move("parry")
	if attacker and attacker.is_alive():
		attacker.cancel_move()
		attacker.stagger(1.6, true)
	parried.emit(attacker)


## Étourdit (dizzy = étoiles au-dessus de la tête) pendant `time` secondes.
func stagger(time: float, dizzy := false) -> void:
	if not is_alive():
		return
	cancel_move()
	blocking = false
	_hit_pending = -1.0
	_stagger_left = time
	visual.clear_flash()
	visual.play_move("dizzy" if dizzy else "stagger")
	visual.set_dizzy(dizzy)


## Équilibre brisé : étourdi, et les coups reçus font 50 % de dégâts en plus.
func break_poise() -> void:
	stagger(2.0, true)
	Combat.popup(self, global_position + Vector3(0, 2.4 * visual.scale.y, 0), "Étourdi", Color("ffd24a"))


## Petit sursaut qui interrompt le coup en cours (monstres légers).
func flinch() -> void:
	cancel_move()
	_hit_pending = -1.0
	_flinch_left = 0.22
	visual.play_move("flinch")


func _on_hurt(_amount: int, _source: Node) -> void:
	pass


# ---------------------------------------------------------------- modificateurs (compétences)

## Multiplicateur de dégâts contre une cible (redéfini par le joueur : rage, exécution...).
func outgoing_multiplier(_target: Combatant) -> float:
	return 1.0


func roll_crit() -> bool:
	return false


func crit_multiplier() -> float:
	return 1.5


## Multiplicateur des dégâts reçus (barrière...).
func incoming_multiplier() -> float:
	return 1.0


func poise_multiplier() -> float:
	return 1.0


## Appelé quand ce combattant vient d'infliger des dégâts.
func _on_damage_dealt(_target: Combatant, _dmg: int) -> void:
	pass


# ---------------------------------------------------------------- états (brûlure, poison, ralentissement)

var _dots: Array = []   # [dps, temps restant, source, couleur, accumulé]
var _slow_left := 0.0
var _slow_factor := 1.0


## Dégâts continus (brûlure, poison) : `dps` dégâts par seconde pendant `time` secondes.
func apply_dot(dps: float, time: float, source: Node, color: Color = Color(1, 0.5, 0.2)) -> void:
	if not is_alive():
		return
	_dots.append([dps, time, source, color, 0.0])


## Ralentit (factor = 0.4 : 40 % de la vitesse) pendant `time` secondes.
func apply_slow(factor: float, time: float) -> void:
	_slow_factor = minf(factor, _slow_factor) if _slow_left > 0.0 else factor
	_slow_left = maxf(_slow_left, time)


func speed_factor() -> float:
	return _slow_factor if _slow_left > 0.0 else 1.0


func _update_states(delta: float) -> void:
	if _slow_left > 0.0:
		_slow_left -= delta
		if _slow_left <= 0.0:
			_slow_factor = 1.0
	var i := 0
	while i < _dots.size():
		var d: Array = _dots[i]
		d[1] -= delta
		d[4] += d[0] * delta
		if d[4] >= 1.0 and is_alive():
			var n := floori(d[4])
			d[4] -= n
			health.take_damage(n, d[2] if is_instance_valid(d[2]) else null)
			if randf() < 0.35:
				Combat.popup(self, global_position + Vector3(0, 1.7 * visual.scale.y, 0), str(n), (d[3] as Color).lightened(0.3))
				VoxelBurst.spawn(self, global_position + Vector3(0, 1.0, 0), d[3], 4, 1.5, 0.08, 0.5, "up", -3.0)
		if d[1] <= 0.0:
			_dots.remove_at(i)
		else:
			i += 1


func _on_died() -> void:
	_hit_pending = -1.0
	_move = {}
	move_name = ""
	_stagger_left = 0.0
	blocking = false
	visual.set_downed(true)
	defeated.emit()


# ---------------------------------------------------------------- à appeler chaque image

func _combat_step(delta: float) -> void:
	_attack_cooldown = maxf(_attack_cooldown - delta, 0.0)
	_invulnerable_left = maxf(_invulnerable_left - delta, 0.0)
	_flinch_left = maxf(_flinch_left - delta, 0.0)
	if blocking:
		_block_time += delta
	if _stagger_left > 0.0:
		_stagger_left -= delta
		if _stagger_left <= 0.0:
			poise = poise_max
			visual.set_dizzy(false)
			visual.stop_move()
	_poise_timer -= delta
	if _poise_timer <= 0.0 and _stagger_left <= 0.0:
		poise = minf(poise_max, poise + poise_max * delta * 0.5)
	_update_move(delta)
	_update_states(delta)
	_knockback = _knockback.move_toward(Vector3.ZERO, 18.0 * delta)


## Déplace le personnage (avec le recul) et le garde sur le sol, hors de l'eau.
func _move_on_ground(delta: float) -> void:
	if _world == null:
		_world = get_tree().get_first_node_in_group("world") as WorldGenerator
	velocity.y = 0.0
	var base := velocity
	velocity = base + _knockback + lunge_velocity()
	var before := global_position
	move_and_slide()
	velocity = base
	if _world:
		global_position = _world.constrain_move(before, global_position)
		global_position.y = lerpf(global_position.y, _world.ground_height_at(global_position), clampf(18.0 * delta, 0.0, 1.0))


## Le combattant ennemi vivant le plus proche dans un rayon (ou null).
func nearest_hostile(radius: float, around: Vector3 = Vector3.INF) -> Combatant:
	var center := global_position if around == Vector3.INF else around
	var best: Combatant = null
	var best_d := radius
	for n in get_tree().get_nodes_in_group(hostile_group()):
		var c := n as Combatant
		if c == null or not c.is_alive() or not c.can_be_targeted():
			continue
		var d := c.global_position.distance_to(center)
		if d < best_d:
			best_d = d
			best = c
	return best


## Faux quand le personnage ne doit pas être pris pour cible (ex. habitant K.O.).
func can_be_targeted() -> bool:
	return is_alive()
