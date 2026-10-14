shader_type spatial;
render_mode diffuse_lambert, specular_disabled, cull_disabled, depth_prepass_alpha;
uniform vec4 roof_color : source_color = vec4(0.43,0.48,0.59,1.0);
uniform bool cutaway = true;
uniform vec2 focus_uv = vec2(0.5);
uniform float cutaway_radius = 0.72;
uniform bool corrugated = true;
uniform float emissive = 0.0;
varying vec3 authored_normal;
void vertex() { authored_normal = normalize(MODELVIEW_NORMAL_MATRIX*NORMAL); }
void fragment() {
 NORMAL = normalize(authored_normal);
 float ribs = 0.5+0.5*sin(UV.y*560.0);
 float seams = smoothstep(0.94,1.0,fract(UV.x*8.0));
 float patches = sin(UV.x*17.0+sin(UV.y*31.0))*sin(UV.y*13.0);
 vec3 paint = pow(roof_color.rgb,vec3(2.2));
 ALBEDO = paint * (corrugated ? 0.72+ribs*0.30-seams*0.18+patches*0.08 : 0.9);
 EMISSION = paint * emissive;
 ROUGHNESS = 0.95;
 SPECULAR = 0.05;
 vec2 offset = SCREEN_UV-focus_uv;
 offset.x *= VIEWPORT_SIZE.x/VIEWPORT_SIZE.y;
 ALPHA = cutaway ? smoothstep(cutaway_radius,cutaway_radius+0.10,length(offset)) : 1.0;
}


