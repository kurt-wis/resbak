shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled, depth_draw_never, depth_test_disabled;
uniform sampler2D scene_color : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform sampler2D scene_depth : hint_depth_texture, repeat_disable, filter_nearest;
uniform vec4 ink : source_color = vec4(0.10,0.09,0.16,1.0);
uniform float stroke_pixels = 1.1;
uniform vec2 playable_min=vec2(-23.6,-14.8);
uniform vec2 playable_max=vec2(23.6,21.7);
// Distance focus (Kurt): sharp within clear_radius metres (XZ) of the hero, fully soft by
// blur_radius, so the far yard reads blurry and comes clear as you walk up to it.
uniform vec3 focus_world=vec3(0.);
uniform float clear_radius=4.5;
uniform float blur_radius=13.0;
uniform float far_softness=4.0;
uniform float distance_focus_enabled=1.0;
uniform vec2 player_focus_uv=vec2(.5,.6);
uniform vec4 haze_color : source_color=vec4(.92,.81,.64,1.);
uniform float paper_finish : hint_range(0., .25) = .10;
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
vec3 world_at(vec2 uv, float depth, mat4 inverse_projection, mat4 inverse_view) {
 #if CURRENT_RENDERER == RENDERER_COMPATIBILITY
 vec3 ndc=vec3(uv,depth)*2.-1.;
 #else
 vec3 ndc=vec3(uv*2.-1.,depth);
 #endif
 vec4 view=inverse_projection*vec4(ndc,1.);
 return (inverse_view*vec4(view.xyz/view.w,1.)).xyz;
}
float focus_blur(vec3 world) {
 return smoothstep(clear_radius,blur_radius,length(world.xz-focus_world.xz));
}
// Explicit taps (two 3x3 rings) also work on Compatibility renderers without screen mipmaps.
// Each tap is weighted by its own blur so the sharp zone never bleeds into the soft one.
vec3 distant_color(vec2 uv, float radius, vec2 texel_size, mat4 inverse_projection, mat4 inverse_view) {
 vec3 total=vec3(0.);
 float weights=0.;
 for(int ring=1;ring<=2;ring++) {
  float r=radius*float(ring)*.5;
  for(int y=-1;y<=1;y++) {
   for(int x=-1;x<=1;x++) {
    if(ring==2&&x==0&&y==0) continue;
    vec2 sample_uv=clamp(uv+vec2(float(x),float(y))*r*texel_size,vec2(0.),vec2(1.));
    vec3 w=world_at(sample_uv,texture(scene_depth,sample_uv).r,inverse_projection,inverse_view);
    float kernel=(x==0?2.:1.)*(y==0?2.:1.)/float(ring);
    float weight=kernel*(.08+focus_blur(w));
    total+=texture(scene_color,sample_uv).rgb*weight;
    weights+=weight;
   }
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
 vec3 world_position=world_at(SCREEN_UV,texture(scene_depth,SCREEN_UV).r,INV_PROJECTION_MATRIX,INV_VIEW_MATRIX);
 vec2 beyond=max(playable_min-world_position.xz,world_position.xz-playable_max);
 float outside=smoothstep(.35,2.35,max(beyond.x,beyond.y));
 // The sharp zone is a circle on the ground around the hero; outside the play area stays soft.
 float distance_blur=max(focus_blur(world_position),outside*.85);
 vec2 player_offset=(SCREEN_UV-player_focus_uv)*vec2(VIEWPORT_SIZE.x/VIEWPORT_SIZE.y,1.);
 distance_blur*=smoothstep(.10,.18,length(player_offset))*distance_focus_enabled;
 vec3 blurred=texture(scene_color,SCREEN_UV).rgb;
 if(distance_blur>.01) {
  blurred=distant_color(SCREEN_UV,far_softness*distance_blur*VIEWPORT_SIZE.y/720.,1.0/VIEWPORT_SIZE,INV_PROJECTION_MATRIX,INV_VIEW_MATRIX);
 }
 blurred=mix(blurred,haze_color.rgb,.13*outside*distance_blur);
 // Shared printed-paint finish: subdued violet shadows, warm paper highlights.
 // Map-specific sunlight and haze still supply the scene's dominant palette.
 float luminance=dot(blurred,vec3(.299,.587,.114));
 vec3 shadow_paint=blurred*vec3(.93,.94,1.05);
 vec3 sun_paint=blurred*vec3(1.03,1.01,.97);
 vec3 painted=mix(shadow_paint,sun_paint,smoothstep(.18,.75,luminance));
 float grain=fract(sin(dot(floor(world_position.xz*180.),vec2(12.9898,78.233)))*43758.5453)-.5;
 blurred=painted+grain*.018;
 float ink_alpha=edge*.70*(1.-distance_blur);
 float blur_alpha=max(distance_blur*.94,paper_finish);
 float combined=ink_alpha+blur_alpha*(1.-ink_alpha);
 ALBEDO=mix(blurred,ink.rgb,ink_alpha/max(combined,.00001));
 ALPHA=combined;
 
}






