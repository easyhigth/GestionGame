// Effets lumineux (étincelles, éclairs, éclats, entailles) : mélange additif, la couleur « brille »
// au-delà de 1 avec le halo de l'image. COLOR : couleur du sommet ou de l'instance (MultiMesh).
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add, shadows_disabled;

uniform vec4 tint : source_color = vec4(1.0);
uniform float energy = 2.0;

void fragment() {
	ALBEDO = tint.rgb * COLOR.rgb * energy * tint.a * COLOR.a;
}
