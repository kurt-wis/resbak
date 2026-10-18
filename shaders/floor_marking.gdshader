shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
// Painted floor markings for the match, drawn on a flat quad (UV 0..1 over `extent` metres).
// mode 0 = base ring: a solid ring at `radius`, a faint fill and a capture progress arc in
//          `progress_color`.
// mode 1 = jail yard: dashed chalk border, diagonal "bars" hatching, darker near the post.
uniform int mode = 0;
uniform vec4 color : source_color = vec4(1.0, 0.8, 0.1, 1.0);
uniform vec4 progress_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec2 extent = vec2(6.0, 6.0); // quad size in metres
uniform float radius = 2.0;
uniform float progress = 0.0;
uniform float pulse = 0.0;
uniform vec2 post_uv = vec2(0.1, 0.5);

float band(float d, float w) {
	return 1.0 - smoothstep(w * 0.5, w * 0.5 + 0.03, abs(d));
}

void fragment() {
	vec2 p = (UV - 0.5) * extent; // metres from the centre
	float a = 0.0;
	vec3 c = color.rgb;
	if (mode == 0) {
		float r = length(p);
		float ring = band(r - radius, 0.16);
		float fill = (1.0 - smoothstep(radius - 0.05, radius, r)) * (0.10 + 0.06 * pulse);
		float ang = atan(p.x, -p.y); // 0 at "north", clockwise
		float t = (ang < 0.0 ? ang + 6.28318 : ang) / 6.28318;
		float arc = band(r - (radius + 0.22), 0.18) * step(t, progress) * step(0.001, progress);
		a = max(ring * 0.95, fill);
		c = mix(c, progress_color.rgb, arc);
		a = max(a, arc);
	} else {
		vec2 half_ext = extent * 0.5;
		vec2 d = half_ext - abs(p);
		float edge = min(d.x, d.y);
		float border = 1.0 - smoothstep(0.10, 0.14, edge);
		float along = (d.x < d.y) ? p.y : p.x;
		border *= step(0.35, fract(along * 0.9));
		float hatch = step(0.82, fract((p.x + p.y) * 0.9)) * 0.16;
		float near_post = 1.0 - smoothstep(0.0, 0.55, distance(UV, post_uv));
		a = max(border * 0.85, hatch + near_post * 0.12);
		a *= step(0.0, edge);
	}
	ALBEDO = c;
	ALPHA = clamp(a, 0.0, 1.0) * color.a;
}
