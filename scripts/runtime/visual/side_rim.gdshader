// Ally/enemy rim (VisualSlots.apply_side): additive fresnel edge, drawn as
// material_overlay so silhouettes stay unchanged. Compatibility/web safe.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back;

uniform vec4 rim_color : source_color = vec4(0.25, 0.95, 0.85, 1.0);
uniform float strength = 0.55;
uniform float power = 2.6;

void fragment() {
	float f = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), power);
	ALBEDO = rim_color.rgb * f * strength;
}
