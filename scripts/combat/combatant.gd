class_name Combatant
extends CharacterBody3D
## Base commune du joueur, des habitants et des monstres : vie, attaque, défense,
## coups au corps à corps ou sorts, recul quand on est touché.
## Chaque combattant a un nœud « Health » et un nœud « Visual » (VoxelCharacter).

signal hurt(amount: int, source: Node)
signal defeated

## Camp : les alliés (joueur, habitants) ou les ennemis (monstres).
enum Team { ALLIES, ENEMIES }

@export var team: Team = Team.ALLIES
## Rayon du corps (pour savoir si un coup touche).
@export var body_radius: float = 0.35
## Portée et vitesse des coups à mains nues.
@export var unarmed_reach: float = 1.3
@export var unarmed_attack_duration: float = 0.34
## Angle (en degrés) couvert par un coup devant soi.
@export var attack_arc: float = 110.0
## Temps d'invulnérabilité après avoir été touché (secondes).
@export var hit_invulnerability: float = 0.35

@onready var visual: VoxelCharacter = $Visual
@onready var health: Health = $Health

var equipment: CharacterEquipment
## Direction regardée.
var facing: Vector3 = Vector3.BACK

var _knockback := Vector3.ZERO
var _hit_pending := -1.0
var _attack_cooldown := 0.0
var _invulnerable_left := 0.0
var _world: WorldGenerator


func _ready() -> void:
	equipment = get_node_or_null("Equipment") as CharacterEquipment
	add_to_group("combatants")
	add_to_group("allies" if team == Team.ALLIES else "enemies")
	health.died.connect(_on_died)
	health.changed.connect(_on_health_changed)
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
	var w := weapon()
	var bonus := equipment.total_attack() if equipment else 0
	if w == null:
		return maxi(1, roundi(base_attack() * 0.6) + bonus)
	return base_attack() + bonus


func defense_power() -> int:
	return base_defense() + (equipment.total_defense() if equipment else 0)


func magic_power() -> int:
	return base_magic() + (equipment.total_magic() if equipment else 0)


func weapon() -> ItemData:
	return equipment.get_item(ItemData.Slot.MAIN_HAND) if equipment else null


func attack_reach() -> float:
	var w := weapon()
	return w.reach if w else unarmed_reach


func attack_duration() -> float:
	var w := weapon()
	return visual.attack_duration / w.attack_speed if w else unarmed_attack_duration


func knockback_strength() -> float:
	var w := weapon()
	return 3.0 + (w.knockback if w else 0.0)


func hostile_group() -> String:
	return "enemies" if team == Team.ALLIES else "allies"


func is_alive() -> bool:
	return health != null and not health.is_dead()


func is_invulnerable() -> bool:
	return _invulnerable_left > 0.0


func is_attacking() -> bool:
	return visual.is_attacking() or _hit_pending > 0.0


func can_attack() -> bool:
	return is_alive() and _attack_cooldown <= 0.0 and not is_attacking()


# ---------------------------------------------------------------- attaque

## Lance un coup vers `facing`. Le coup touche au milieu de l'animation.
func start_attack() -> bool:
	if not can_attack():
		return false
	var dur := attack_duration()
	visual.play_attack(dur)
	_hit_pending = dur * 0.42
	_attack_cooldown = dur + 0.08
	return true


func _deliver_hit() -> void:
	var w := weapon()
	if w and w.projectile:
		var bolt := MagicBolt.new()
		bolt.shooter = self
		bolt.direction = Vector3(facing.x, 0, facing.z).normalized()
		bolt.damage = magic_power()
		bolt.range_left = w.reach
		var holder: Node = get_tree().current_scene if get_tree().current_scene else get_tree().root
		holder.add_child(bolt)
		bolt.global_position = global_position + Vector3(0, 1.0, 0) + bolt.direction * 0.6
		return
	var hits := Combat.melee(self, attack_reach(), attack_arc, attack_power(), knockback_strength())
	_on_attack_landed(hits)


## Appelé après un coup au corps à corps (nombre de cibles touchées).
func _on_attack_landed(_hits: int) -> void:
	pass


# ---------------------------------------------------------------- dégâts reçus

## Reçoit un coup de puissance `attack`. Renvoie vrai si le coup a porté.
func receive_hit(attack: int, source: Node3D, knockback := 3.0) -> bool:
	if not is_alive() or is_invulnerable():
		return false
	var dmg := Combat.compute_damage(attack, defense_power())
	health.take_damage(dmg, source)
	_invulnerable_left = hit_invulnerability
	visual.flash()
	var color := Color("ffe070") if team == Team.ENEMIES else Color("ff5a4a")
	Combat.popup(self, global_position + Vector3(0, 2.0 * visual.scale.y, 0), str(dmg), color, dmg >= 15)
	if source:
		var away := global_position - source.global_position
		away.y = 0.0
		if away.length_squared() > 0.0001:
			_knockback = away.normalized() * knockback
	hurt.emit(dmg, source)
	_on_hurt(dmg, source)
	return true


func _on_hurt(_amount: int, _source: Node) -> void:
	pass


func _on_died() -> void:
	_hit_pending = -1.0
	visual.set_downed(true)
	defeated.emit()


func _on_health_changed(_c: int, _m: int) -> void:
	pass


# ---------------------------------------------------------------- à appeler chaque image

func _combat_step(delta: float) -> void:
	_attack_cooldown = maxf(_attack_cooldown - delta, 0.0)
	_invulnerable_left = maxf(_invulnerable_left - delta, 0.0)
	if _hit_pending > 0.0:
		_hit_pending -= delta
		if _hit_pending <= 0.0 and is_alive():
			_deliver_hit()
	_knockback = _knockback.move_toward(Vector3.ZERO, 18.0 * delta)


## Déplace le personnage (avec le recul) et le garde sur le sol, hors de l'eau.
func _move_on_ground(delta: float) -> void:
	if _world == null:
		_world = get_tree().get_first_node_in_group("world") as WorldGenerator
	velocity.y = 0.0
	velocity += _knockback
	var before := global_position
	move_and_slide()
	velocity -= _knockback
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
