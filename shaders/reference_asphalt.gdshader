shader_type spatial;
render_mode diffuse_lambert,specular_disabled;
uniform sampler2D wear_texture : source_color,repeat_enable,filter_linear_mipmap;
varying vec3 world_position;
void vertex(){world_position=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;}
void fragment(){
 vec3 wear=texture(wear_texture,world_position.xz*.075).rgb;
 float value=dot(wear,vec3(.3,.5,.2));
 float painted=clamp(1.+(value-.27)*4.,.65,1.35);
 ALBEDO=vec3(.29,.295,.28)*(.60+painted*.40);
 ROUGHNESS=1.;SPECULAR=0.;
}

