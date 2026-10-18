shader_type spatial;
render_mode diffuse_lambert, specular_disabled, cull_disabled;
uniform sampler2D mural_texture : source_color, repeat_disable, filter_linear_mipmap_anisotropic;
uniform bool fit_surface = false;
uniform vec3 surface_center = vec3(0.0);
uniform vec3 surface_size = vec3(1.0);
uniform float repeat_width = 8.0;
uniform float repeat_height = 2.3;
uniform bool barriers_only = false;
varying vec3 local_position;
varying vec3 local_normal;
varying vec3 world_position;
varying vec3 world_normal;
varying vec3 axis_scale;
void vertex() {
 local_position = VERTEX;
 local_normal = NORMAL;
 world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
 world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
 axis_scale = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
}
float mirror_coordinate(float u) { return 1.0 - abs(mod(u, 2.0) - 1.0); }
void fragment() {
 bool side = abs(local_normal.x) > abs(local_normal.z);
 float horizontal = side ? local_position.z - surface_center.z : local_position.x - surface_center.x;
 float physical_height = max(surface_size.y * axis_scale.y, 0.01);
 float horizontal_scale = side ? axis_scale.z : axis_scale.x;
 vec2 uv;
 if (fit_surface) {
  uv = vec2(0.5 + horizontal * horizontal_scale / (3.0 * physical_height), 0.5 - (local_position.y - surface_center.y) / max(surface_size.y, 0.01));
 } else {
  float world_horizontal = abs(world_normal.x) > abs(world_normal.z) ? world_position.z : world_position.x;
  uv = vec2(world_horizontal / repeat_width, 0.5 - world_position.y / repeat_height);
 }
 uv.x = mirror_coordinate(uv.x);
 uv.y = fit_surface ? clamp(uv.y, 0.001, 0.999) : mirror_coordinate(uv.y);
 vec3 paint = texture(mural_texture, clamp(uv, vec2(0.001), vec2(0.999))).rgb;
 float face_width = (side ? surface_size.z * axis_scale.z : surface_size.x * axis_scale.x);
 float cap = smoothstep(0.55, 0.85, abs(world_normal.y));
 if (fit_surface && face_width < 0.25) { cap = 1.0; }
 ALBEDO = mix(paint, vec3(0.96, 0.72, 0.21), cap);
 if (barriers_only && (abs(world_position.x) > 13.0 || world_position.z < -6.5 || world_position.z > 7.3 || world_position.y > 1.5)) { ALBEDO = vec3(0.78, 0.77, 0.70); }
 ROUGHNESS = 0.95;
 SPECULAR = 0.0;
}