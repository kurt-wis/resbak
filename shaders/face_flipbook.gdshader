shader_type spatial;
// Painted mouth / eyelid cards on a hero's head (tools/build_face_cards.py). One atlas, one frame
// shown at a time (frame 0 is fully transparent = "nothing painted over the model's own face").
// Lit with the same toon bands as character_toon so the card reads as part of the skin.
render_mode diffuse_toon, specular_disabled, blend_mix, depth_draw_never, cull_back;
uniform sampler2D atlas : source_color, filter_linear_mipmap;
uniform int atlas_cols = 3;
uniform int atlas_rows = 2;
uniform int frame = 0;
// Pulls the card towards the camera in clip space so it never z-fights the head it sits on.
// (Positive is "nearer" in this project's renderer; the opposite sign hides most of the card.)
uniform float depth_bias : hint_range(0.0, 0.01) = 0.0004;

void vertex() {
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	clip.z += depth_bias * clip.w;
	POSITION = clip;
}

void fragment() {
	int col = frame % atlas_cols;
	int row = frame / atlas_cols;
	vec2 cell = vec2(1.0 / float(atlas_cols), 1.0 / float(atlas_rows));
	vec2 uv = (vec2(float(col), float(row)) + clamp(UV, vec2(0.001), vec2(0.999))) * cell;
	vec4 t = texture(atlas, uv);
	ALBEDO = t.rgb;
	ALPHA = t.a;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	float rim = pow(1.0 - max(dot(normalize(NORMAL), normalize(VIEW)), 0.0), 3.0);
	EMISSION = ALBEDO * rim * 0.10;
}

void light() {
	float facing = max(dot(NORMAL, LIGHT), 0.0);
	float band = mix(0.25, 1.0, smoothstep(0.20, 0.65, facing));
	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * ATTENUATION * band / 3.14159;
}
