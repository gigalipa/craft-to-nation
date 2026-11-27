shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_front;

uniform vec3 glow_color : source_color = vec3(1.0, 0.85, 0.55);
uniform float intensity : hint_range(0.0, 2.0) = 0.25;

void fragment() {
	float fresnel = pow(clamp(dot(-NORMAL, VIEW), 0.0, 1.0), 2.4);
	ALBEDO = glow_color * intensity * fresnel;
	ALPHA = clamp(fresnel * intensity, 0.0, 1.0);
}
