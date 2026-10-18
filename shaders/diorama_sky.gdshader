shader_type sky;
// Golden-hour sky for the Home diorama: a warm-to-blue gradient, a low sun's glow and soft
// cumulus lit from the sun side. The camera only sees about -18..+22 degrees of elevation, so the
// gradient is tuned for that sliver. Clouds drift on a small circle that closes every loop, so
// the 48 s diorama loop has no sky pop.
uniform vec3 top_color : source_color = vec3(0.10, 0.20, 0.42);
uniform vec3 mid_color : source_color = vec3(0.34, 0.50, 0.72);
uniform vec3 horizon_color : source_color = vec3(1.0, 0.62, 0.36);
uniform vec3 glow_color : source_color = vec3(1.0, 0.70, 0.36);
uniform vec3 cloud_lit : source_color = vec3(1.0, 0.89, 0.72);
uniform vec3 cloud_shade : source_color = vec3(0.62, 0.44, 0.50);
uniform vec3 sun_dir = vec3(0.74, 0.34, -0.58); // unit vector toward the sun
uniform float cloud_cover : hint_range(0.0, 1.0) = 0.52;
uniform float phase = 0.0; // loop time / loop length, 0..1

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1, 0)), f.x),
			mix(hash21(i + vec2(0, 1)), hash21(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) {
	float a = 0.5;
	float s = 0.0;
	for (int i = 0; i < 5; i++) {
		s += a * vnoise(p);
		p = p * 2.03 + vec2(17.1, 9.2);
		a *= 0.5;
	}
	return s;
}

void sky() {
	vec3 d = normalize(EYEDIR);
	vec3 sd = normalize(sun_dir);
	float h = max(d.y, 0.0);
	vec3 col = mix(horizon_color, mid_color, smoothstep(0.0, 0.20, h));
	col = mix(col, top_color, smoothstep(0.16, 0.60, h));
	float s = max(dot(d, sd), 0.0);
	col += glow_color * (pow(s, 5.0) * 0.45 + pow(s, 36.0) * 0.6);
	if (d.y > 0.0) {
		float a = phase * 6.2831853;
		vec2 drift = vec2(cos(a), sin(a)) * 0.35;
		vec2 uv = d.xz / (d.y + 0.14) * 0.85 + drift + vec2(3.7, 1.3);
		float n = fbm(uv);
		float c = smoothstep(1.0 - cloud_cover, 1.0 - cloud_cover + 0.22, n);
		c *= smoothstep(0.0, 0.10, d.y); // thin out into the horizon haze
		float n2 = fbm(uv + sd.xz * 0.12);
		float lit = clamp((n - n2) * 5.0 + 0.55, 0.0, 1.0);
		vec3 cc = mix(cloud_shade, cloud_lit, lit);
		cc = mix(cc, horizon_color, (1.0 - smoothstep(0.0, 0.35, h)) * 0.5); // warm toward the horizon
		cc += glow_color * pow(s, 4.0) * 0.35;
		col = mix(col, cc, c * 0.92);
	}
	COLOR = col;
}
