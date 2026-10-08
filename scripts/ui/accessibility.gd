extends CanvasLayer
## Autoload « Access » : confort visuel. Filtre pour les daltoniens (toute l'image, interface comprise)
## et mouvement réduit (moins de secousses de caméra, ralentis et arrêts sur image plus courts).
## Les réglages sont dans SaveGame.options (« colorblind », « reduce_motion »).

const MODES := ["Aucun", "Protanopie (rouge)", "Deutéranopie (vert)", "Tritanopie (bleu)"]
## Matrices de correction (daltonisation) : chaque ligne donne un canal de sortie.
const MATRICES := [
	[Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1)],
	[Vector3(0.0, 0.9, 0.1), Vector3(0.0, 1.0, 0.0), Vector3(0.0, 0.3, 0.7)],
	[Vector3(1.0, 0.0, 0.0), Vector3(0.7, 0.3, 0.0), Vector3(0.0, 0.3, 0.7)],
	[Vector3(1.0, 0.0, 0.0), Vector3(0.0, 0.8, 0.2), Vector3(0.0, 0.5, 0.5)],
]
const SHADER := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform vec3 row_r = vec3(1.0, 0.0, 0.0);
uniform vec3 row_g = vec3(0.0, 1.0, 0.0);
uniform vec3 row_b = vec3(0.0, 0.0, 1.0);
void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	COLOR = vec4(dot(row_r, c), dot(row_g, c), dot(row_b, c), 1.0);
}
"""

var _rect: ColorRect
var _mat: ShaderMaterial


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rect = ColorRect.new()
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var sh := Shader.new()
	sh.code = SHADER
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	_rect.material = _mat
	add_child(_rect)
	_rect.visible = false


## Applique le mode (0 = aucun). Le filtre n'est rendu que s'il sert.
func set_colorblind(mode: int) -> void:
	mode = clampi(mode, 0, MODES.size() - 1)
	if _rect == null:
		return
	_rect.visible = mode > 0
	var m: Array = MATRICES[mode]
	_mat.set_shader_parameter("row_r", m[0])
	_mat.set_shader_parameter("row_g", m[1])
	_mat.set_shader_parameter("row_b", m[2])


func reduce_motion() -> bool:
	return bool(SaveGame.options.get("reduce_motion", false))


## Force d'un tremblement de caméra une fois l'option prise en compte.
func shake_scale() -> float:
	return 0.15 if reduce_motion() else 1.0
