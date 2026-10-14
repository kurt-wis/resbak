shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
uniform sampler2D painted_ground : source_color, filter_linear_mipmap;
uniform sampler2D painted_concrete : source_color, filter_linear_mipmap;
void fragment() {
 vec2 uv = UV;
 if (uv.x < 0.125) { uv.x = uv.x/0.125*0.03; }
 else if (uv.x > 0.875) { uv.x = 0.97+(uv.x-0.875)/0.125*0.03; }
 else { uv.x = 0.03+(uv.x-0.125)/0.75*0.94; }
 if (uv.y < 0.1333) { uv.y = uv.y/0.1333*0.088; }
 else if (uv.y < 0.667) { uv.y = 0.088+(uv.y-0.1333)/0.5337*0.581; }
 vec3 color = texture(painted_ground,uv).rgb;
 if ((UV.x < 0.125 || UV.x > 0.875) && UV.y < 0.733) {
 color = texture(painted_concrete,UV*vec2(6.0,4.5)).rgb;
 }
 ALBEDO = color*0.88;
 ROUGHNESS = 1.0;
 SPECULAR = 0.0;
}


