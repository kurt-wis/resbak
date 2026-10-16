shader_type spatial;
render_mode diffuse_lambert,specular_disabled,cull_disabled;
uniform vec2 panel_size=vec2(13.,1.);
void fragment(){
 vec2 cells=UV*panel_size/vec2(.20,.153);
 vec2 edge=min(fract(cells),1.-fract(cells));
 vec2 aa=max(fwidth(cells),vec2(.0001));
 vec2 strand=1.-smoothstep(vec2(.024),vec2(.024)+aa*.65,edge);
 float weave=max(strand.x,strand.y);
 ALBEDO=vec3(.16,.17,.15);
 ALPHA=weave;
 ALPHA_SCISSOR_THRESHOLD=.38;
 ROUGHNESS=1.;SPECULAR=0.;
}
