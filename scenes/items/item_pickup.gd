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

var _display: Node3D
var _t := randf() * TAU
var _taken := false


func _ready() -> void:
	add_to_group("pickups")
	body_entered.connect(_on_body_entered)
	_build()


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
