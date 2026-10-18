shader_type spatial;
// character_toon.gdshader with an alpha uniform, for heroes seen through (IYAK! 25 %).
// HeroVisual swaps it in only while alpha < 1 so opaque heroes keep the cheap pass.
render_mode blend_mix, depth_draw_always, diffuse_toon, specular_disabled;
uniform sampler2D base_texture : source_color, filter_linear_mipmap;
uniform vec4 base_color : source_color = vec4(1.0);
uniform float alpha : hint_range(0.0, 1.0) = 0.25;
uniform float ward_strength : hint_range(0.0, 1.0) = 0.0;

void fragment() {
 ALBEDO = texture(base_texture, UV).rgb * base_color.rgb;
 ROUGHNESS = 1.0;
 SPECULAR = 0.0;
 float rim = pow(1.0-max(dot(normalize(NORMAL),normalize(VIEW)),0.0),3.0);
 EMISSION = ALBEDO * rim * 0.10;
 ALPHA = alpha;
	float ward_rim = pow(1.0 - max(dot(normalize(NORMAL), normalize(VIEW)), 0.0), 1.8);
	ALBEDO = mix(ALBEDO, vec3(0.95, 0.035, 0.055), ward_strength * 0.35);
	EMISSION += vec3(1.0, 0.025, 0.04) * ward_strength * (0.25 + ward_rim * 1.5);

}

void light() {
 float facing = max(dot(NORMAL,LIGHT),0.0);
 float band = mix(0.25,1.0,smoothstep(0.20,0.65,facing));
 DIFFUSE_LIGHT += ALBEDO*LIGHT_COLOR*ATTENUATION*band/3.14159;
}
