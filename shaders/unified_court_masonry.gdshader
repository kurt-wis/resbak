shader_type spatial;
render_mode diffuse_lambert,specular_disabled;
uniform sampler2D concrete_texture : source_color,repeat_enable,filter_linear_mipmap;
varying vec3 p;
varying vec3 n;
void vertex(){p=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;n=normalize(MODEL_NORMAL_MATRIX*NORMAL);}
void fragment(){
 vec3 w=pow(abs(n),vec3(6));w/=max(dot(w,vec3(1)),.001);
 vec3 uv=p*.23;
 vec3 tex=texture(concrete_texture,uv.zy).rgb*w.x+texture(concrete_texture,uv.xz).rgb*w.y+texture(concrete_texture,uv.xy).rgb*w.z;
 vec3 wear=mix(vec3(1),clamp(tex/vec3(.53,.54,.60),vec3(.7),vec3(1.3)),.38);
 vec3 plaster=vec3(.39,.375,.38);
 vec3 blue=vec3(.12,.17,.22);
 // Same world-height paint division and material on both walls and posts.
 float upper=smoothstep(.39,.415,p.y);
 ALBEDO=mix(blue,plaster,upper)*wear*2.0;
 ROUGHNESS=1.;SPECULAR=0.;
}

