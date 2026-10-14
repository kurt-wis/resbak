shader_type spatial;
render_mode unshaded, cull_front;
uniform vec4 ink_color : source_color = vec4(0.055, 0.045, 0.075, 1.0);
uniform float outline_pixels : hint_range(0.0, 8.0) = 3.5;
void vertex() {
 vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
 vec3 view_normal = MODELVIEW_NORMAL_MATRIX * NORMAL;
 vec2 projected = (PROJECTION_MATRIX * vec4(view_normal, 0.0)).xy;
 float magnitude = length(projected);
 if (magnitude > 0.0001) {
  clip.xy += projected / magnitude * outline_pixels * 2.0 / VIEWPORT_SIZE * clip.w;
 }
 clip.z -= 0.00001 * clip.w;
 POSITION = clip;
}
void fragment() { ALBEDO = ink_color.rgb; }



