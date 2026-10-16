shader_type spatial;
render_mode diffuse_lambert,specular_disabled,cull_disabled,depth_draw_never;
uniform vec2 panel_size=vec2(3.,2.);
void fragment(){
 vec2 p=UV*panel_size*3.2;
 vec2 diamond=vec2(p.x+p.y,p.x-p.y);
 vec2 d=abs(fract(diamond)-.5);
 float line=min(d.x,d.y);
 float aa=max(fwidth(diamond.x),fwidth(diamond.y))*.55;
 float wire=1.-smoothstep(.018,.018+aa,line);
 ALBEDO=vec3(.40,.42,.38);
 ALPHA=wire*.72;
 ROUGHNESS=1.;SPECULAR=0.;
}


