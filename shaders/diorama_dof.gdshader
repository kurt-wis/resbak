shader_type spatial;
render_mode unshaded, depth_test_disabled, cull_disabled, fog_disabled;
// Depth-of-field for the Home diorama (Compatibility has no built-in DoF). A full-screen quad
// parented to the camera reads the colour + depth buffers and blurs everything behind `focus_end`
// with a 24-tap golden-angle disc. Taps are weighted by their own blur so the crisp heroes do not
// bleed a halo into the soft backdrop. Only the far side is blurred; the foreground stays sharp.
uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;
uniform sampler2D depth_tex : hint_depth_texture, repeat_disable, filter_nearest;
uniform float blur_start = 9.0;  // metres from the camera where defocus begins
uniform float blur_end = 26.0;   // metres where it reaches full strength
uniform float radius = 0.0065;   // blur radius at full strength, as a fraction of viewport height
const int TAPS = 24;

float view_dist(vec2 uv, mat4 inv_proj) {
	float depth = textureLod(depth_tex, uv, 0.0).x;
	vec3 ndc = vec3(uv, depth) * 2.0 - 1.0; // Compatibility (OpenGL) depth convention
	vec4 v = inv_proj * vec4(ndc, 1.0);
	return -v.z / v.w;
}
float coc(float dist) {
	return smoothstep(blur_start, blur_end, dist);
}

void vertex() {
	POSITION = vec4(VERTEX.xy, 0.0, 1.0);
}

void fragment() {
	vec2 px = 1.0 / VIEWPORT_SIZE;
	float centre = coc(view_dist(SCREEN_UV, INV_PROJECTION_MATRIX));
	float r_px = centre * radius * VIEWPORT_SIZE.y;
	vec3 base = textureLod(screen_tex, SCREEN_UV, 0.0).rgb;
	if (r_px < 0.4) {
		ALBEDO = base;
	} else {
		vec3 acc = base;
		float wsum = 1.0;
		for (int i = 0; i < TAPS; i++) {
			float r = sqrt((float(i) + 0.5) / float(TAPS));
			float a = float(i) * 2.399963;
			vec2 uv = SCREEN_UV + vec2(cos(a), sin(a)) * r * r_px * px;
			float sc = coc(view_dist(uv, INV_PROJECTION_MATRIX));
			float w = max(clamp(sc / max(centre, 0.001), 0.0, 1.0), 0.04);
			acc += textureLod(screen_tex, uv, 0.0).rgb * w;
			wsum += w;
		}
		ALBEDO = acc / wsum;
	}
}
