shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
uniform sampler2D painted_ground : source_color, filter_linear_mipmap;
varying vec3 world_position;
void vertex() { world_position = (MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
 vec2 uv = vec2((world_position.x+20.0)/40.0,(world_position.z+12.0)/30.0);
 if (uv.x < 0.125) { uv.x = uv.x/0.125*0.03; }
 else if (uv.x > 0.875) { uv.x = 0.97+(uv.x-0.875)/0.125*0.03; }
 else { uv.x = 0.03+(uv.x-0.125)/0.75*0.94; }
 ALBEDO = texture(painted_ground,uv).rgb*0.88;
 ROUGHNESS = 1.0;
 SPECULAR = 0.0;
}
