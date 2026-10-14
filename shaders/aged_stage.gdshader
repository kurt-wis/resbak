shader_type spatial;
render_mode diffuse_lambert,specular_disabled;
uniform sampler2D wood_texture : source_color,repeat_enable,filter_linear_mipmap;
varying vec3 p;
varying vec3 n;
void vertex(){p=(MODEL_MATRIX*vec4(VERTEX,1)).xyz;n=normalize(MODEL_NORMAL_MATRIX*NORMAL);}
void fragment(){
 // World coordinates preserve matching grain scale across platform and stairs.
 vec3 w=pow(abs(n),vec3(6));w/=max(dot(w,vec3(1)),.001);
 vec3 wood=texture(wood_texture,p.zy*.28).rgb*w.x+texture(wood_texture,p.xz*.28).rgb*w.y+texture(wood_texture,p.xy*.28).rgb*w.z;
 ALBEDO=wood*1.25;
 ROUGHNESS=1.;SPECULAR=0.;
}

