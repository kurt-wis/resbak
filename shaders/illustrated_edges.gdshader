shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled, depth_draw_never, depth_test_disabled;
uniform sampler2D scene_color : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform sampler2D scene_depth : hint_depth_texture, repeat_disable, filter_nearest;
uniform vec4 ink : source_color = vec4(0.10,0.09,0.16,1.0);
uniform float stroke_pixels = 1.1;
uniform vec2 playable_min=vec2(-23.6,-14.8);
uniform vec2 playable_max=vec2(23.6,21.7);
uniform float focus_depth=12.5;
uniform float clear_range=2.0;
uniform float fade_range=13.0;
uniform float far_softness=2.4;
uniform float distance_focus_enabled=1.0;
uniform vec2 player_focus_uv=vec2(.5,.6);
uniform vec4 haze_color : source_color=vec4(.92,.81,.64,1.);
float view_depth(vec2 uv, mat4 inverse_projection) {
 float depth = texture(scene_depth,uv).r;
 #if CURRENT_RENDERER == RENDERER_COMPATIBILITY
 vec3 ndc = vec3(uv,depth)*2.0-1.0;
 #else
 vec3 ndc = vec3(uv*2.0-1.0,depth);
 #endif
 vec4 view = inverse_projection*vec4(ndc,1.0);
 return -view.z/view.w;
}
// Explicit taps also work on mobile Compatibility renderers without screen mipmaps.
vec3 distant_color(vec2 uv, float radius, vec2 texel_size, mat4 inverse_projection) {
 vec3 total=vec3(0.);
 float weights=0.;
 for(int y=-1;y<=1;y++) {
  for(int x=-1;x<=1;x++) {
   vec2 sample_uv=clamp(uv+vec2(float(x),float(y))*radius*texel_size,vec2(0.),vec2(1.));
   float sample_depth=view_depth(sample_uv,inverse_projection);
   float kernel=(x==0?2.:1.)*(y==0?2.:1.);
   float weight=kernel*smoothstep(focus_depth+clear_range-1.,focus_depth+clear_range+1.,sample_depth);
   total+=texture(scene_color,sample_uv).rgb*weight;
   weights+=weight;
  }
 }
 return total/max(weights,.0001);
}
void vertex() { POSITION = vec4(VERTEX.xy,1.0,1.0); }
void fragment() {
 vec2 step_uv = stroke_pixels / VIEWPORT_SIZE;
 float center = view_depth(SCREEN_UV, INV_PROJECTION_MATRIX);
 float left = view_depth(SCREEN_UV-vec2(step_uv.x,0.0), INV_PROJECTION_MATRIX);
 float right = view_depth(SCREEN_UV+vec2(step_uv.x,0.0), INV_PROJECTION_MATRIX);
 float up = view_depth(SCREEN_UV-vec2(0.0,step_uv.y), INV_PROJECTION_MATRIX);
 float down = view_depth(SCREEN_UV+vec2(0.0,step_uv.y), INV_PROJECTION_MATRIX);
 float discontinuity = abs(left+right-2.0*center)+abs(up+down-2.0*center);
 float edge = smoothstep(0.055,0.22,discontinuity);
 float raw_depth=texture(scene_depth,SCREEN_UV).r;
 #if CURRENT_RENDERER == RENDERER_COMPATIBILITY
 vec3 ndc=vec3(SCREEN_UV,raw_depth)*2.-1.;
 #else
 vec3 ndc=vec3(SCREEN_UV*2.-1.,raw_depth);
 #endif
 vec4 view_position=INV_PROJECTION_MATRIX*vec4(ndc,1.);
 view_position/=view_position.w;
 vec3 world_position=(INV_VIEW_MATRIX*view_position).xyz;
 vec2 beyond=max(playable_min-world_position.xz,world_position.xz-playable_max);
 float outside=smoothstep(.35,2.35,max(beyond.x,beyond.y));
 // The sharp zone follows the character's depth, including when the camera arm retracts.
 float distance_blur=smoothstep(focus_depth+clear_range,focus_depth+fade_range,center);
 distance_blur=max(distance_blur,outside*.85*smoothstep(focus_depth-1.,focus_depth+8.,center));
 vec2 player_offset=(SCREEN_UV-player_focus_uv)*vec2(VIEWPORT_SIZE.x/VIEWPORT_SIZE.y,1.);
 distance_blur*=smoothstep(.10,.18,length(player_offset))*distance_focus_enabled;
 vec3 blurred=texture(scene_color,SCREEN_UV).rgb;
 if(distance_blur>.01) {
  blurred=distant_color(SCREEN_UV,far_softness*distance_blur*VIEWPORT_SIZE.y/720.,1.0/VIEWPORT_SIZE,INV_PROJECTION_MATRIX);
 }
 blurred=mix(blurred,haze_color.rgb,.13*outside*distance_blur);
 float ink_alpha=edge*.70*(1.-distance_blur);
 float blur_alpha=distance_blur*.94;
 float combined=ink_alpha+blur_alpha*(1.-ink_alpha);
 ALBEDO=mix(blurred,ink.rgb,ink_alpha/max(combined,.00001));
 ALPHA=combined;
 
}






