class_name HealthBar3D
extends MeshInstance3D
## Petite barre de vie qui flotte au-dessus d'un personnage (toujours face à la caméra).

const SHADER := preload("res://scripts/combat/health_bar.gdshader")

@export var bar_size := Vector2(0.9, 0.11)
@export var fill_color := Color(0.86, 0.22, 0.16)
## Cacher la barre quand la vie est pleine.
@export var hide_when_full := true

var _mat: ShaderMaterial
var _shown := 0.0


func _ready() -> void:
	var q := QuadMesh.new()
	q.size = bar_size
	mesh = q
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.set_shader_parameter("fill_color", fill_color)
	_mat.render_priority = 5
	material_override = _mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visible = not hide_when_full


func set_ratio(r: float) -> void:
	_mat.set_shader_parameter("fill", clampf(r, 0.0, 1.0))
	visible = r > 0.0 and (r < 0.999 or not hide_when_full)
