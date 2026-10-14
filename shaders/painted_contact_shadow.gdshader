shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
void fragment() {
 float distance_from_center = length((UV-vec2(0.5))*2.0);
 ALBEDO = vec3(0.055,0.045,0.075);
 ALPHA = (1.0-smoothstep(0.20,1.0,distance_from_center))*0.22;
}
