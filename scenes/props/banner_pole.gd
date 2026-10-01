class_name BannerPole
extends Node3D
## Étendard aux couleurs du royaume (voir Heraldry) : un mât, une bannière à deux couleurs et l'emblème.
## Sert pour les étendards posés autour du village et pour le meuble « Étendard ».

var _cloth: StandardMaterial3D
var _band: StandardMaterial3D
var _labels: Array[Label3D] = []


func _ready() -> void:
	add_to_group("banners")
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.45, 0.32, 0.2)
	_box(Vector3(0.12, 3.2, 0.12), Vector3(0, 1.6, 0), wood)
	_box(Vector3(0.9, 0.08, 0.08), Vector3(0.4, 3.05, 0), wood)
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(0.92, 0.72, 0.25)
	gold.metallic = 0.6
	_box(Vector3(0.2, 0.2, 0.2), Vector3(0, 3.3, 0), gold)
	_cloth = StandardMaterial3D.new()
	_box(Vector3(0.8, 1.3, 0.04), Vector3(0.45, 2.35, 0), _cloth)
	_band = StandardMaterial3D.new()
	_box(Vector3(0.82, 0.18, 0.05), Vector3(0.45, 1.75, 0), _band)
	_box(Vector3(0.82, 0.12, 0.05), Vector3(0.45, 2.95, 0), _band)
	for side in [-1.0, 1.0]:
		var l := Label3D.new()
		l.font_size = 64
		l.pixel_size = 0.008
		l.outline_size = 8
		l.position = Vector3(0.45, 2.4, 0.04 * side)
		l.rotation.y = 0.0 if side > 0 else PI
		add_child(l)
		_labels.append(l)
	var h := get_tree().get_first_node_in_group("heraldry") if is_inside_tree() else null
	apply(h)


func _box(size: Vector3, pos: Vector3, mat: StandardMaterial3D) -> void:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	m.mesh = b
	m.position = pos
	m.material_override = mat
	add_child(m)


## Prend les couleurs et l'emblème du royaume (h : Heraldry, ou null pour les couleurs par défaut).
func apply(h: Node) -> void:
	if _cloth == null:
		return
	var p: Color = h.primary_color() if h else Color("8a1e2e")
	var s: Color = h.secondary_color() if h else Color("e0b030")
	_cloth.albedo_color = p
	_band.albedo_color = s
	for l in _labels:
		l.text = h.emblem_char() if h else "♛"
		l.modulate = s
		l.outline_modulate = p.darkened(0.5)
