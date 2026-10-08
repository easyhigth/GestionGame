extends CanvasLayer
## Autoload « Access » : confort visuel. Filtre pour les daltoniens (toute l'image, interface comprise)
## et mouvement réduit (moins de secousses de caméra, ralentis et arrêts sur image plus courts).
## Les réglages sont dans SaveGame.options (« colorblind », « reduce_motion »).

const MODES := ["Aucun", "Protanopie (rouge)", "Deutéranopie (vert)", "Tritanopie (bleu)"]
## Pour chaque mode : [simulation de la vue (matrices de Machado, 3 lignes), report de l'erreur (3 lignes)].
## Le filtre « daltonise » l'image : il simule ce que voit le daltonien, mesure ce qui lui échappe et le reporte
## sur les couleurs qu'il distingue (les verts et les rouges deviennent distincts sans changer l'allure du jeu).
const MATRICES := [
	[[Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1)], [Vector3(0, 0, 0), Vector3(0, 0, 0), Vector3(0, 0, 0)]],
	[[Vector3(0.152286, 1.052583, -0.204868), Vector3(0.114503, 0.786281, 0.099216), Vector3(-0.003882, -0.048116, 1.051998)],
		[Vector3(0, 0, 0), Vector3(0.7, 1, 0), Vector3(0.7, 0, 1)]],
	[[Vector3(0.367322, 0.860646, -0.227968), Vector3(0.280085, 0.672501, 0.047413), Vector3(-0.011820, 0.042940, 0.968881)],
		[Vector3(0, 0, 0), Vector3(0.7, 1, 0), Vector3(0.7, 0, 1)]],
	[[Vector3(1.255528, -0.076749, -0.178779), Vector3(-0.078411, 0.930809, 0.147602), Vector3(0.004733, 0.691367, 0.303900)],
		[Vector3(0, 0, 0.7), Vector3(0, 0, 0.7), Vector3(0, 0, 0)]],
]
const SHADER := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform vec3 sim_r = vec3(1.0, 0.0, 0.0);
uniform vec3 sim_g = vec3(0.0, 1.0, 0.0);
uniform vec3 sim_b = vec3(0.0, 0.0, 1.0);
uniform vec3 shift_r = vec3(0.0);
uniform vec3 shift_g = vec3(0.0);
uniform vec3 shift_b = vec3(0.0);
void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	vec3 sim = vec3(dot(sim_r, c), dot(sim_g, c), dot(sim_b, c));
	vec3 err = c - sim;
	vec3 fixed_c = c + vec3(dot(shift_r, err), dot(shift_g, err), dot(shift_b, err));
	COLOR = vec4(clamp(fixed_c, 0.0, 1.0), 1.0);
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
	for i in 3:
		_mat.set_shader_parameter("sim_" + "rgb"[i], m[0][i])
		_mat.set_shader_parameter("shift_" + "rgb"[i], m[1][i])


func reduce_motion() -> bool:
	return bool(SaveGame.options.get("reduce_motion", false))


## Force d'un tremblement de caméra une fois l'option prise en compte.
func shake_scale() -> float:
	return 0.15 if reduce_motion() else 1.0
