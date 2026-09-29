class_name Villager
extends Combatant
## Habitant du village : se promène autour de sa maison, ramasse les armes et armures
## qui traînent près de lui et les équipe si elles sont meilleures que les siennes.
## Armé, il défend le village contre les monstres ; sans arme, il s'enfuit.
## À 0 point de vie il tombe K.O. puis se relève un peu plus tard.
## La race se choisit dans l'Inspecteur (ou par le générateur de monde).

const NAMES := ["Aldric", "Brunhild", "Cassian", "Dagna", "Elric", "Fenna", "Garrick", "Hilda",
	"Ivar", "Jorun", "Kael", "Liora", "Magnus", "Nessa", "Orin", "Perrine", "Quentin", "Rowena",
	"Sigrid", "Thorin", "Ulric", "Vesna", "Wendel", "Yselle", "Zora", "Anselme", "Bérénice", "Corentin"]

@export var race: RaceData
## Nom affiché (tiré au hasard si vide).
@export var villager_name: String = ""
## Vitesse de marche, en mètres par seconde.
@export var walk_speed: float = 1.4
## Distance max (en mètres) autour du point de départ.
@export var wander_radius: float = 4.0
@export var min_pause: float = 1.0
@export var max_pause: float = 3.5
## Distance (en mètres) à laquelle l'habitant repère un équipement au sol.
@export var loot_radius: float = 9.0
## Distance à laquelle il repère un monstre.
@export var alert_radius: float = 9.0
## Il ne poursuit pas un monstre à plus de cette distance de sa maison.
@export var defend_radius: float = 16.0
## Durée du K.O. (secondes).
@export var knockout_time: float = 20.0

@onready var label: Label3D = $Label

var home: Vector3
var _target := Vector3.ZERO
var _pause := 0.0
var _fetch: ItemPickup
var _scan_timer := randf()
var _threat: Combatant
var _threat_timer := randf() * 0.5
var _ko_left := 0.0


func _ready() -> void:
	super()
	add_to_group("villagers")
	if villager_name.is_empty():
		villager_name = NAMES.pick_random()
	home = global_position
	_target = home
	_pause = randf_range(0.0, max_pause)
	facing = Vector3.FORWARD.rotated(Vector3.UP, randf() * TAU)
	set_race(race)


func set_race(new_race: RaceData) -> void:
	race = new_race
	var vis := get_node_or_null("Visual") as VoxelCharacter
	if race == null or vis == null:
		return
	vis.set_equipment_library(race.equipment)
	if not race.villager_models.is_empty():
		vis.set_model(race.villager_models.pick_random())
	elif race.model:
		vis.set_model(race.model)
	var hp := get_node_or_null("Health") as Health
	if hp:
		hp.set_max(race.max_health, true)


func base_attack() -> int:
	return race.strength if race else 10


func base_magic() -> int:
	return race.magic if race else 10


func can_be_targeted() -> bool:
	return is_alive() and _ko_left <= 0.0


func _on_died() -> void:
	super()
	_ko_left = knockout_time
	_fetch = null
	_threat = null


func _on_hurt(_amount: int, source: Node) -> void:
	# riposte si on a une arme
	if source is Combatant and weapon() != null:
		_threat = source


func _physics_process(delta: float) -> void:
	_combat_step(delta)
	if not is_alive():
		_ko_left -= delta
		velocity = Vector3.ZERO
		_move_on_ground(delta)
		visual.animate(delta, Vector3.ZERO, facing)
		label.visible = false
		if _ko_left <= 0.0:
			health.revive(0.5)
			visual.set_downed(false)
			_invulnerable_left = 2.0
		return
	_threat_timer -= delta
	if _threat_timer <= 0.0:
		_threat_timer = 0.4
		_update_threat()
	if _threat:
		_fight_or_flee(delta)
		return
	_scan_timer -= delta
	if _scan_timer <= 0.0:
		_scan_timer = 1.5
		_look_for_loot()
	var speed := walk_speed * (race.speed_multiplier if race else 1.0) * equipment.speed_multiplier()
	if _fetch and (not is_instance_valid(_fetch) or _fetch.is_taken()):
		_fetch = null
		_pause = randf_range(min_pause, max_pause)
	if _fetch:
		_target = _fetch.global_position
		_pause = 0.0
		speed *= 1.6
	if _pause > 0.0:
		_pause -= delta
		velocity = Vector3.ZERO
		if _pause <= 0.0:
			var off := Vector2.from_angle(randf() * TAU) * randf_range(0.7, wander_radius)
			_target = home + Vector3(off.x, 0, off.y)
	else:
		var to_target := _target - global_position
		to_target.y = 0.0
		if to_target.length() < 0.15:
			_pause = randf_range(min_pause, max_pause)
			velocity = Vector3.ZERO
		else:
			facing = to_target.normalized()
			velocity = facing * speed
	var before := global_position
	_move_on_ground(delta)
	# bloqué contre un obstacle : on s'arrête et on repart ailleurs
	if _pause <= 0.0 and velocity.length() > 0.0 and Vector2(global_position.x - before.x, global_position.z - before.z).length() < 0.005:
		_pause = randf_range(min_pause, max_pause)
		_fetch = null
	visual.animate(delta, velocity, facing)
	_update_label()


## Choisit le monstre à combattre (ou à fuir).
func _update_threat() -> void:
	if _threat and (not is_instance_valid(_threat) or not _threat.is_alive() \
			or _threat.global_position.distance_to(home) > defend_radius + 4.0):
		_threat = null
	if _threat == null:
		var t := nearest_hostile(alert_radius)
		if t and t.global_position.distance_to(home) <= defend_radius:
			_threat = t
			_fetch = null


func _fight_or_flee(delta: float) -> void:
	var to := _threat.global_position - global_position
	to.y = 0.0
	var dist := to.length()
	var speed := walk_speed * 2.2 * (race.speed_multiplier if race else 1.0) * equipment.speed_multiplier()
	var w := weapon()
	if w == null:
		# pas d'arme : on court se mettre à l'abri derrière sa maison
		var away := (home - _threat.global_position)
		away.y = 0.0
		var goal := home + away.normalized() * 3.0
		var dir := goal - global_position
		dir.y = 0.0
		velocity = dir.normalized() * speed if dir.length() > 0.4 else Vector3.ZERO
		if velocity != Vector3.ZERO:
			facing = velocity.normalized()
		if dist > alert_radius + 3.0:
			_threat = null
	else:
		if dist > 0.01:
			facing = to / dist
		var reach := attack_reach()
		var wanted := minf(reach * 0.85, 6.0) if w.projectile else reach * 0.8
		if dist > wanted:
			velocity = facing * speed
		else:
			velocity = Vector3.ZERO
			start_attack()
	if is_attacking():
		velocity *= 0.3
	_move_on_ground(delta)
	visual.animate(delta, velocity, facing)
	_update_label()


## Cherche un équipement au sol meilleur que le sien.
func _look_for_loot() -> void:
	if _fetch:
		return
	var best: ItemPickup = null
	var best_gain := 0.0
	for p in get_tree().get_nodes_in_group("pickups"):
		var pickup := p as ItemPickup
		if pickup == null or pickup.is_taken() or pickup.item == null or not pickup.item.is_equipment():
			continue
		if pickup.global_position.distance_to(global_position) > loot_radius:
			continue
		if not equipment.is_upgrade(pickup.item):
			continue
		var cur := equipment.get_item(pickup.item.slot)
		var gain := pickup.item.power() - (cur.power() if cur else 0.0)
		if gain > best_gain:
			best_gain = gain
			best = pickup
	_fetch = best


## Appelé par un objet au sol quand l'habitant marche dessus.
func try_pickup(pickup: ItemPickup) -> void:
	var item := pickup.item
	if item == null or pickup.is_taken() or not equipment.is_upgrade(item):
		return
	pickup.take()
	# l'ancien objet est reposé au sol
	for old in equipment.equip(item):
		_drop(old)
	_fetch = null
	_pause = 0.6


func _drop(item: ItemData) -> void:
	if _world:
		_world.spawn_pickup(item, global_position + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized() * 1.2)


func _update_label() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var near := player != null and player.global_position.distance_to(global_position) < 2.4
	label.visible = near
	if near:
		label.text = "%s (%s)\n[E] Équipement" % [villager_name, race.display_name if race else "?"]


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
	return "%s (%s)" % [villager_name, race.display_name if race else "?"]
