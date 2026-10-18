shader_type spatial;
render_mode diffuse_burley, specular_disabled;
// Home-diorama set pieces (store, facades, ground, boxes). Grades the saturated Meshy palettes
// toward weathered, warm, painted-concrete tones, lights softly (no hard bands) and adds a
// world-space grain so flat colours stop reading as plastic.
uniform sampler2D base_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 base_color : source_color = vec4(1.0);
uniform bool use_texture = true;
uniform vec2 uv_scale = vec2(1.0); // tiles the texture (ground slabs and building fronts)
uniform float saturation : hint_range(0.0, 1.5) = 0.85;
uniform float value_gain : hint_range(0.3, 1.5) = 1.02;
uniform vec3 tint : source_color = vec3(1.0, 0.97, 0.92);
uniform bool remap_palette = false;
uniform vec3 teal_to : source_color = vec3(0.74, 0.80, 0.66); // dusty mint
uniform vec3 orange_to : source_color = vec3(0.56, 0.27, 0.17); // weathered terracotta
uniform float grain_strength : hint_range(0.0, 0.5) = 0.07;
uniform float grain_scale = 5.0;
uniform float patch_strength : hint_range(0.0, 0.5) = 0.06;
uniform float patch_scale = 0.35;
uniform float grime_height = 0.9; // metres: soot/damp darkening toward the ground
uniform float grime_strength : hint_range(0.0, 0.6) = 0.10;
varying vec3 wpos;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.1, 0.2, 0.3));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}
float vnoise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i + vec3(0, 0, 0)), hash(i + vec3(1, 0, 0)), f.x),
			mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
			mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x),
			mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}
vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 c = base_color.rgb;
	if (use_texture) {
		c *= texture(base_texture, UV * uv_scale).rgb;
	}
	vec3 hsv = rgb2hsv(c);
	if (remap_palette) {
		// teal band (~0.45-0.58) -> mint, orange band (~0.0-0.1 or >0.96) -> terracotta
		float teal = smoothstep(0.40, 0.46, hsv.x) * (1.0 - smoothstep(0.56, 0.64, hsv.x)) * smoothstep(0.25, 0.5, hsv.y);
		float org = (1.0 - smoothstep(0.06, 0.12, hsv.x) + smoothstep(0.94, 0.99, hsv.x)) * smoothstep(0.35, 0.6, hsv.y);
		org = clamp(org, 0.0, 1.0);
		vec3 lum_keep = vec3(hsv.z);
		c = mix(c, teal_to * (0.55 + 0.6 * hsv.z), teal);
		c = mix(c, orange_to * (0.6 + 0.6 * hsv.z), org);
	}
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(l), c, saturation) * value_gain * tint;
	float g = vnoise(wpos * grain_scale) * 0.6 + vnoise(wpos * grain_scale * 2.7) * 0.4;
	float p = vnoise(wpos * patch_scale + vec3(7.0, 3.0, 1.0));
	c *= 1.0 + (g - 0.5) * 2.0 * grain_strength + (p - 0.5) * 2.0 * patch_strength;
	float grime = 1.0 - smoothstep(0.0, grime_height, wpos.y);
	c *= 1.0 - grime * grime_strength * (0.6 + 0.8 * vnoise(wpos * 3.0));
	ALBEDO = c;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

void light() {
	// soft wrapped diffuse: a gentle terminator instead of a hard 2-band toon step; the cast
	// shadow still drops the sun out, the (cool) ambient fills it.
	float nl = dot(NORMAL, LIGHT);
	float wrap = clamp(nl * 0.5 + 0.5, 0.0, 1.0);
	float soft = smoothstep(0.30, 0.85, wrap);
	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * ATTENUATION * soft / 3.14159;
}
