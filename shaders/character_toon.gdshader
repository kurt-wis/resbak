shader_type spatial;
render_mode diffuse_toon, specular_disabled;
uniform sampler2D base_texture : source_color, filter_linear_mipmap;
uniform vec4 base_color : source_color = vec4(1.0);
void fragment() {
 ALBEDO = texture(base_texture, UV).rgb * base_color.rgb;
 ROUGHNESS = 1.0;
 SPECULAR = 0.0;
 float rim = pow(1.0-max(dot(normalize(NORMAL),normalize(VIEW)),0.0),3.0);
 EMISSION = ALBEDO * rim * 0.10;
}

void light() {
 float facing = max(dot(NORMAL,LIGHT),0.0);
 float band = mix(0.25,1.0,smoothstep(0.20,0.65,facing));
 DIFFUSE_LIGHT += ALBEDO*LIGHT_COLOR*ATTENUATION*band/3.14159;
}
