shader_type spatial;
render_mode diffuse_toon, specular_disabled;
uniform sampler2D paint_texture : source_color, filter_linear_mipmap;
void fragment() {
 vec3 color = texture(paint_texture,UV).rgb;
 float gold = smoothstep(0.02,0.12,color.r-color.b) * smoothstep(0.01,0.08,color.g-color.b);
 float brightness = clamp(dot(color,vec3(0.3,0.6,0.1))/0.35,0.35,1.5);
 ALBEDO = mix(color,vec3(0.36,0.095,0.52)*brightness,gold);
 ROUGHNESS = 1.0;
 SPECULAR = 0.0;
}
