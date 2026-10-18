shader_type spatial;
render_mode diffuse_lambert,specular_disabled;
uniform sampler2D paint_texture : source_color, filter_linear_mipmap;
void fragment() {
 vec3 original = texture(paint_texture, UV).rgb;
 float lightness = dot(original, vec3(0.299,0.587,0.114));
 float saturation = max(max(original.r,original.g),original.b)-min(min(original.r,original.g),original.b);
 float neutral = (1.0-smoothstep(0.08,0.25,saturation))*smoothstep(0.18,0.48,lightness);
 ALBEDO = mix(original,vec3(1.0,0.58,0.055)*(0.65+0.45*lightness),neutral*0.94);
 ROUGHNESS = 0.9;
}
