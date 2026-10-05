class_name CampBorder
extends Node3D
## Les bornes de la zone du camp : un cercle de piquets à fanion aux couleurs du royaume autour du drapeau.
## Le rayon suit le rang du royaume (WorldGenerator.home_radius) ; rien tant que le drapeau n'est pas planté.

var world: WorldGenerator
var _posts: MultiMeshInstance3D
var _flags: MultiMeshInstance3D
var _built_for := Vector3(-1, -1, -1)


func _ready() -> void:
	add_to_group("camp_border")
	world = get_parent() as WorldGenerator
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.45, 0.32, 0.2)
	_posts = _multi(Vector3(0.12, 1.1, 0.12), wood)
	_flags = _multi(Vector3(0.04, 0.26, 0.4), null)
	if world:
		world.home_changed.connect(refresh)
	refresh()


func _multi(size: Vector3, mat: StandardMaterial3D) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var box := BoxMesh.new()
	box.size = size
	mm.mesh = box
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if mat:
		mi.material_override = mat
	add_child(mi)
	return mi


func _process(_delta: float) -> void:
	# le royaume monte de rang : la zone s'agrandit
	if world and world.has_home() and not is_equal_approx(world.home_radius(), _built_for.z):
		var grew := _built_for.z > 0.0 and world.home_radius() > _built_for.z
		refresh()
		var p := get_tree().get_first_node_in_group("player")
		if grew and p:
			p.notify.emit("Ton royaume grandit : la zone du camp s'étend (%d m autour du drapeau)." % roundi(world.home_radius()))


## Replace les bornes autour du drapeau (ou les retire s'il n'y en a pas).
func refresh() -> void:
	if world == null:
		return
	if not world.has_home():
		_posts.multimesh.instance_count = 0
		_flags.multimesh.instance_count = 0
		_built_for = Vector3(-1, -1, -1)
		return
	var c := world.home_center()
	var r := world.home_radius()
	_built_for = Vector3(c.x, c.z, r)
	var n := maxi(16, roundi(TAU * r / 5.0))
	_posts.multimesh.instance_count = n
	_flags.multimesh.instance_count = n
	var h = get_tree().get_first_node_in_group("heraldry")
	var col: Color = h.primary_color() if h else Color("8a1e2e")
	var fm := StandardMaterial3D.new()
	fm.albedo_color = col
	_flags.material_override = fm
	for i in n:
		var a := TAU * i / n
		var x := c.x + cos(a) * r
		var z := c.z + sin(a) * r
		var cell := world.cell_at(Vector3(x, 0, z))
		world._ensure_chunk_of(cell)
		var y := world.terrain_height(cell)
		var basis := Basis(Vector3.UP, -a)
		_posts.multimesh.set_instance_transform(i, Transform3D(basis, Vector3(x, y + 0.55, z)))
		_flags.multimesh.set_instance_transform(i, Transform3D(basis, Vector3(x, y + 0.95, z) + basis.z * 0.2))
