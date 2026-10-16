shader_type spatial;
render_mode diffuse_lambert,specular_disabled;
uniform vec4 base_color : source_color;
uniform float roof=0.;
uniform float roof_axis=0.;
uniform sampler2D roof_texture : source_color,repeat_enable,filter_linear_mipmap;
uniform float stucco=0.;
uniform sampler2D wear_texture : source_color,repeat_enable,filter_linear_mipmap;
uniform sampler2D fine_texture : source_color,repeat_enable,filter_linear_mipmap;
varying vec3 p;
varying vec3 n;
float hash21(vec2 v){return fract(sin(dot(v,vec2(127.1,311.7)))*43758.5453);}
float soft_noise(vec2 q){vec2 c=floor(q);vec2 f=fract(q);f=f*f*(3.-2.*f);return mix(mix(hash21(c),hash21(c+vec2(1,0)),f.x),mix(hash21(c+vec2(0,1)),hash21(c+vec2(1,1)),f.x),f.y);}
void vertex(){p=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;n=normalize(MODEL_NORMAL_MATRIX*NORMAL);}
void fragment(){
 vec3 w=pow(abs(n),vec3(6.));w/=max(dot(w,vec3(1.)),.001);
 vec3 wear=texture(wear_texture,p.zy*.12).rgb*w.x+texture(wear_texture,p.xz*.12).rgb*w.y+texture(wear_texture,p.xy*.12).rgb*w.z;
 vec3 fine=texture(fine_texture,p.zy*.38).rgb*w.x+texture(fine_texture,p.xz*.38).rgb*w.y+texture(fine_texture,p.xy*.38).rgb*w.z;
 float grain=clamp((dot(fine,vec3(.3,.5,.2))-.27)*.5,-.045,.045);
 float weather=clamp((dot(wear,vec3(.3,.5,.2))-.27)*.35,-.045,.035);
 vec2 projection=abs(n.y)>.5?p.xz:(abs(n.x)>abs(n.z)?p.zy:p.xy);
 float brush=(soft_noise(projection*.24)-.5)*.045;
 ALBEDO=base_color.rgb*(.99+grain+weather+brush);
 // Restrained wear belongs to painted walls, not every concrete slab.
 float chipped=stucco*smoothstep(.005,.035,wear.r-wear.b);
 ALBEDO*=1.-chipped*.11;
 vec2 roof_uv=roof_axis<.5?vec2(p.z*.38,p.x*.23):vec2(p.x*.38,p.z*.23);
 ALBEDO=mix(ALBEDO,texture(roof_texture,roof_uv).rgb*.94,roof);
 ROUGHNESS=1.;SPECULAR=0.;
}
