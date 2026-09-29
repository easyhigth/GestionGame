shader_type spatial;
render_mode unshaded, depth_test_disabled, cull_disabled, shadows_disabled;

uniform float fill = 1.0;
uniform vec4 fill_color : source_color = vec4(0.86, 0.22, 0.16, 1.0);
uniform vec4 back_color : source_color = vec4(0.08, 0.06, 0.06, 1.0);

void vertex() {
	// toujours face à la caméra
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
	vec2 uv = UV;
	bool inside = uv.x > 0.03 && uv.x < 0.97 && uv.y > 0.2 && uv.y < 0.8;
	float x = (uv.x - 0.03) / 0.94;
	vec3 c = back_color.rgb;
	if (inside) {
		c = x <= fill ? fill_color.rgb * (uv.y < 0.45 ? 1.2 : 1.0) : vec3(0.22, 0.18, 0.16);
	}
	ALBEDO = c;
}
