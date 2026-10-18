shader_type spatial;
render_mode unshaded, cull_disabled;
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}
void fragment() {
	vec2 p = abs(UV * 2.0 - 1.0);
	float edge = max(max(p.x, p.y), (p.x + p.y) * 0.65);
	if (edge > 1.0) discard;
	ALBEDO = edge > 0.86 ? vec3(1.0, 0.85, 0.9) : vec3(0.58, 0.025, 0.12);
}
