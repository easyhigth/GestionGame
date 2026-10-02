class_name ItemPickup
extends Area3D
## Objet posé au sol : il flotte et tourne. Le joueur (ou un habitant) le ramasse en marchant dessus.

@export var item: ItemData:
	set(v):
		item = v
		if is_inside_tree():
			_build()
@export var count: int = 1
@export var spin_speed: float = 1.4
@export var float_height: float = 0.45

## Durée de vie au sol (comme dans Minecraft) : 10 minutes, 30 pour les objets rares ou mieux.
const LIFETIME := 600.0
const LIFETIME_RARE := 1800.0
## Les objets identiques empilables tombés à moins de cette distance se regroupent.
const MERGE_DISTANCE := 1.5

var _display: Node3D
var _t := randf() * TAU
var _taken := false
var _age := 0.0
## Loin du héros, l'objet « dort » : pas de détection de collision ni d'animation (vérifié 2 fois par seconde).
const AWAKE_DISTANCE := 30.0
var _check := randf() * 0.5
var _awake := true
static var _player: Node3D


func _ready() -> void:
	add_to_group("pickups")
	body_entered.connect(_on_body_entered)
	_build()
	_try_merge.call_deferred()


## Fusionne avec un tas identique tout proche (moins de nœuds et de zones de collision).
func _try_merge() -> void:
	if _taken or item == null or item.max_stack <= 1 or not is_inside_tree():
		return
	for other in get_tree().get_nodes_in_group("pickups"):
		if other == self or other.is_taken() or other.item != item or other.count + count > item.max_stack:
			continue
		if (other as Node3D).global_position.distance_to(global_position) < MERGE_DISTANCE:
			other.count += count
			_taken = true
			queue_free()
			return


func _build() -> void:
	if _display:
		_display.queue_free()
		_display = null
	if item == null:
		return
	_display = Items.build_display(item, 0.75 if item.is_equipment() else 0.55)
	add_child(_display)
	var ring := $Ring as MeshInstance3D
	if ring:
		var mat := ring.material_override as StandardMaterial3D
		if mat:
			mat = mat.duplicate()
			var c := item.rarity_color()
			mat.albedo_color = Color(c, 0.55)
			mat.emission = c
			ring.material_override = mat


func _process(delta: float) -> void:
	_t += delta
	_age += delta
	# les objets tombés disparaissent avec le temps (pas ceux que le monde a semés : ils sont comptés par case)
	if _age > (LIFETIME_RARE if item and item.rarity >= ItemData.Rarity.RARE else LIFETIME) and not _taken and not has_meta("world_loot"):
		take()
		return
	_check -= delta
	if _check <= 0.0:
		_check = 0.5
		if _player == null or not is_instance_valid(_player):
			_player = get_tree().get_first_node_in_group("player") as Node3D
		var near := _player == null or _player.global_position.distance_squared_to(global_position) < AWAKE_DISTANCE * AWAKE_DISTANCE
		if near != _awake:
			_awake = near
			set_deferred("monitoring", near and not _taken)
	if not _awake:
		return
	if _display:
		_display.rotation.y += spin_speed * delta
		_display.position.y = float_height + sin(_t * 2.0) * 0.08


func _on_body_entered(body: Node) -> void:
	if not _taken and body.has_method("try_pickup"):
		body.try_pickup(self)


## Appelé par le personnage qui a ramassé l'objet.
func take() -> void:
	_taken = true
	set_deferred("monitoring", false)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ONE * 0.01, 0.18)
	tw.tween_callback(queue_free)


func is_taken() -> bool:
	return _taken
