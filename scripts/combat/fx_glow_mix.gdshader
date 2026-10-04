// Effets lumineux opaques par endroits (boules de feu, cercles de runes) : mélange normal, couleur
// poussée au-delà de 1 pour briller avec le halo de l'image.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, shadows_disabled;

uniform vec4 tint : source_color = vec4(1.0);
uniform float energy = 2.0;

void fragment() {
	ALBEDO = tint.rgb * COLOR.rgb * energy;
	ALPHA = clamp(tint.a * COLOR.a, 0.0, 1.0);
}
