class_name VoxelBurst
extends MultiMeshInstance3D
## Gerbe de petits cubes (étincelles d'impact, onde de choc, éclatement d'un monstre vaincu).
## Se détruit toute seule à la fin.

var _pos: Array[Vector3] = []
var _vel: Array[Vector3] = []
var _age: Array[float] = []
var _life: Array[float] = []
var _size: Array[float] = []
var _rot: Array[Vector3] = []
var gravity := 9.0
var drag := 2.0
var color := Color.WHITE
var glow := true


## Crée une gerbe à `pos`. `mode` : "sphere" (toutes directions), "ring" (onde au sol), "up" (vers le haut).
static func spawn(parent: Node, pos: Vector3, col: Color, count: int, speed: float, size: float,
		life: float, mode := "sphere", grav := 9.0, emissive := true) -> VoxelBurst:
	var b := VoxelBurst.new()
	b.color = col
	b.gravity = grav
	b.glow = emissive
	for i in count:
		var dir: Vector3
		match mode:
			"ring":
				var a := TAU * i / count + randf() * 0.2
				dir = Vector3(cos(a), randf_range(0.05, 0.25), sin(a))
			"up":
				dir = Vector3(randf_range(-0.5, 0.5), 1.0, randf_range(-0.5, 0.5)).normalized()
			_:
				dir = Vector3(randf_range(-1, 1), randf_range(-0.3, 1), randf_range(-1, 1)).normalized()
		b._pos.append(pos + dir * 0.05)
		b._vel.append(dir * speed * randf_range(0.6, 1.2))
		b._age.append(0.0)
		b._life.append(life * randf_range(0.7, 1.2))
		b._size.append(size * randf_range(0.6, 1.3))
		b._rot.append(Vector3(randf() * TAU, randf() * TAU, 0))
	var holder: Node = parent.get_tree().current_scene if parent.get_tree().current_scene else parent.get_tree().root
	holder.add_child(b)
	return b


func _ready() -> void:
	top_level = true
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if glow else BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	box.material = mat
	mm.mesh = box
	mm.instance_count = _pos.size()
	multimesh = mm
	global_transform = Transform3D.IDENTITY


func _process(delta: float) -> void:
	var alive := 0
	var mm := multimesh
	for i in _pos.size():
		_age[i] += delta
		var k := _age[i] / _life[i]
		if k >= 1.0:
			mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * 0.0001), _pos[i]))
			continue
		alive += 1
		_vel[i].y -= gravity * delta
		_vel[i] *= maxf(0.0, 1.0 - drag * delta)
		_pos[i] += _vel[i] * delta
		_rot[i] += Vector3(6, 4, 0) * delta
		var s := _size[i] * (1.0 - k * k)
		mm.set_instance_transform(i, Transform3D(Basis.from_euler(_rot[i]).scaled(Vector3.ONE * s), _pos[i]))
		mm.set_instance_color(i, Color(color, 1.0 - k * 0.6))
	if alive == 0:
		queue_free()
