shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back;
uniform vec4 spirit_color : source_color = vec4(1.0, 0.65, 0.12, 1.0);
uniform float opacity = 1.0;
varying vec3 local_point;
void vertex() { local_point = VERTEX; }
void fragment() {
	float rim = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 2.5);
	float scan = smoothstep(0.65, 1.0, sin(local_point.y * 100.0 - TIME * 5.0));
	ALBEDO = mix(spirit_color.rgb, vec3(1.0, 0.94, 0.65), rim);
	ALPHA = opacity * (0.035 + rim * 0.62 + scan * 0.055);
}
