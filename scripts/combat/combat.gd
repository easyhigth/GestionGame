class_name Combat
extends RefCounted
## Règles du combat : calcul des dégâts, coups au corps à corps, chiffres de dégâts,
## et « jetons d'attaque » (pas plus de 2 monstres qui frappent la même cible à la fois).

## Plus c'est haut, moins l'armure protège.
const ARMOR_SCALE := 40.0
## Nombre de monstres qui peuvent attaquer la même cible en même temps.
const MAX_ATTACKERS := 2

static var _tokens := {}   # cible (id) -> [attaquants]


## Dégâts d'une attaque `attack` contre une défense `defense` (±15 % de hasard, 1 minimum).
static func compute_damage(attack: int, defense: int) -> int:
	var raw := float(attack) * ARMOR_SCALE / (ARMOR_SCALE + maxf(defense, 0.0))
	return maxi(1, roundi(raw * randf_range(0.85, 1.15)))


## Frappe tous les adversaires dans un arc devant `attacker`. Renvoie le nombre de cibles touchées.
## Ceux qui sont juste hors de portée sont prévenus (pour l'esquive parfaite).
static func melee(attacker: Combatant, reach: float, arc_degrees: float, attack: int, knockback: float, poise := 1.0) -> int:
	var hits := 0
	var fwd := Vector2(attacker.facing.x, attacker.facing.z).normalized()
	var origin := attacker.global_position
	for n in attacker.get_tree().get_nodes_in_group(attacker.hostile_group()):
		var target := n as Combatant
		if target == null or not target.is_alive():
			continue
		var off := Vector2(target.global_position.x - origin.x, target.global_position.z - origin.z)
		var dist := off.length()
		if absf(target.global_position.y - origin.y) > 1.6:
			continue
		var in_arc := dist < 0.3 or absf(rad_to_deg(fwd.angle_to(off.normalized()))) <= arc_degrees * 0.5
		if not in_arc:
			continue
		if dist > reach + target.body_radius:
			if dist < reach + target.body_radius + 1.4:
				target.notify_near_miss(attacker)
			continue
		if target.receive_hit(attack, attacker, knockback, poise):
			hits += 1
	return hits


## Demande le droit d'attaquer `target`. Renvoie vrai si accordé.
static func take_token(target: Node, attacker: Node) -> bool:
	var key := target.get_instance_id()
	var list: Array = _tokens.get(key, [])
	list = list.filter(func(a): return is_instance_valid(a) and a.is_alive())
	if attacker in list:
		_tokens[key] = list
		return true
	if list.size() >= MAX_ATTACKERS:
		_tokens[key] = list
		return false
	list.append(attacker)
	_tokens[key] = list
	return true


static func release_token(target: Node, attacker: Node) -> void:
	if target == null:
		return
	var key := target.get_instance_id()
	if _tokens.has(key):
		(_tokens[key] as Array).erase(attacker)


## Petit chiffre ou mot qui s'envole au-dessus de la cible.
static func popup(parent: Node, pos: Vector3, text: String, color: Color, big := false) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var l := Label3D.new()
	l.text = text
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.font_size = 64 if big else 48
	l.outline_size = 14
	l.pixel_size = 0.006
	l.modulate = color
	l.outline_modulate = Color(0.06, 0.04, 0.04)
	l.render_priority = 10
	l.outline_render_priority = 9
	var holder: Node = parent.get_tree().current_scene
	if holder == null:
		holder = parent.get_tree().root
	holder.add_child(l)
	l.global_position = pos + Vector3(randf_range(-0.25, 0.25), 0, randf_range(-0.1, 0.1))
	l.scale = Vector3.ONE * 0.4
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "scale", Vector3.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "global_position:y", l.global_position.y + 0.9, 0.8).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(l, "modulate:a", 0.0, 0.35).set_delay(0.45)
	tw.tween_property(l, "outline_modulate:a", 0.0, 0.35).set_delay(0.45)
	tw.chain().tween_callback(l.queue_free)
