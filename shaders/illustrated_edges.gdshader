shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled, depth_draw_never, depth_test_disabled;
uniform sampler2D scene_color : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform sampler2D scene_depth : hint_depth_texture, repeat_disable, filter_nearest;
uniform vec4 ink : source_color = vec4(0.10,0.09,0.16,1.0);
uniform float stroke_pixels = 1.1;
uniform vec2 playable_min=vec2(-23.6,-14.8);
uniform vec2 playable_max=vec2(23.6,21.7);
uniform float outside_softness=1.8;
uniform vec4 haze_color : source_color=vec4(.816,.776,.718,1.);
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
 vec3 color = texture(scene_color,SCREEN_UV).rgb;
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
 vec3 blurred=textureLod(scene_color,SCREEN_UV,outside_softness).rgb;
 float gray=dot(blurred,vec3(.3,.5,.2));
 blurred=mix(blurred,vec3(gray),.14);
 blurred=mix(blurred,haze_color.rgb,.16);
 float ink_alpha=edge*.70*(1.-outside);
 float blur_alpha=outside*.72;
 float combined=ink_alpha+blur_alpha*(1.-ink_alpha);
 ALBEDO=mix(blurred,ink.rgb,ink_alpha/max(combined,.00001));
 ALPHA=combined;
 
}




