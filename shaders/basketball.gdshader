shader_type spatial;
render_mode diffuse_toon, specular_disabled;
// The base "flag": a toon basketball. Seams are drawn from the object-space normal so the
// ball needs no texture: the equator, one meridian and two curved side seams, plus a faint
// pebble grain. Lit like the heroes (character_toon.gdshader bands).
uniform vec4 leather : source_color = vec4(0.93, 0.45, 0.13, 1.0);
uniform vec4 seam : source_color = vec4(0.10, 0.07, 0.07, 1.0);
uniform vec4 team_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float tint_amount : hint_range(0.0, 1.0) = 0.0;
uniform float seam_width = 0.045;
varying vec3 obj_n;

void vertex() {
	obj_n = normalize(VERTEX);
}

float line(float d, float w) {
	return 1.0 - smoothstep(w * 0.6, w, abs(d));
}

void fragment() {
	vec3 n = normalize(obj_n);
	float s = line(n.y, seam_width);
	s = max(s, line(n.x, seam_width));
	// curved side seams: |z| follows a bow that leans toward the poles
	float bow = 0.70 - 0.45 * n.y * n.y;
	s = max(s, line(abs(n.z) - bow, seam_width));
	float grain = fract(sin(dot(floor(n * 90.0), vec3(12.9898, 78.233, 37.719))) * 43758.5453);
	vec3 base = mix(leather.rgb, team_tint.rgb, tint_amount) * (0.94 + 0.08 * grain);
	ALBEDO = mix(base, seam.rgb, s);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	float rim = pow(1.0 - max(dot(normalize(NORMAL), normalize(VIEW)), 0.0), 3.0);
	EMISSION = ALBEDO * rim * 0.18;
}

void light() {
	float facing = max(dot(NORMAL, LIGHT), 0.0);
	float band = mix(0.32, 1.0, smoothstep(0.20, 0.65, facing));
	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * ATTENUATION * band / 3.14159;
}
