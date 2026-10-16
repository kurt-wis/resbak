shader_type spatial;
render_mode diffuse_lambert,specular_disabled;
uniform sampler2D wear_texture : source_color,repeat_enable,filter_linear_mipmap;
uniform sampler2D fine_texture : source_color,repeat_enable,filter_linear_mipmap;
varying vec3 p;
void vertex(){p=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;}
void fragment(){
 float broad=dot(texture(wear_texture,p.xz*.07).rgb,vec3(.3,.5,.2));
 float grain=dot(texture(fine_texture,p.xz*.65).rgb,vec3(.3,.5,.2));
 float variation=clamp((broad-.27)*.32,-.04,.04)+clamp((grain-.27)*.25,-.025,.025);
 ALBEDO=vec3(.255,.263,.255)*(1.+variation);
 ROUGHNESS=1.;SPECULAR=0.;
}
