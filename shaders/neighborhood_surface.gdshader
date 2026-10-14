shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
uniform vec4 tint : source_color = vec4(.3,.3,.3,1.0);
uniform sampler2D painted_surface : source_color, repeat_enable, filter_linear_mipmap;
varying vec3 world_pos;
void vertex(){world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
void fragment(){
 vec2 p=world_pos.xz;
 float grain=hash(floor(p*35.0));
 float patch=hash(floor(p*1.7));
 float joints=step(.985,fract(p.x*.65))*step(.8,patch);
 vec3 paint=texture(painted_surface,p*.18).rgb;
 float wear=clamp(dot(paint,vec3(.3,.5,.2))/.26,.65,1.3);
 ALBEDO=tint.rgb*wear*(.94+grain*.06)*(1.0-joints*.25);
 ROUGHNESS=1.0; SPECULAR=0.0;
}

