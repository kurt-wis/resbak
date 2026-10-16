shader_type spatial;
render_mode diffuse_lambert,specular_disabled;
uniform vec4 base_color : source_color;
uniform float roof = 0.;
uniform float roof_axis = 0.;
uniform sampler2D roof_texture : source_color,repeat_enable,filter_linear_mipmap;
uniform float stucco = 0.;
uniform sampler2D wear_texture : source_color,repeat_enable,filter_linear_mipmap;
varying vec3 p;
varying vec3 n;
void vertex(){p=(MODEL_MATRIX*vec4(VERTEX,1)).xyz;n=normalize(MODEL_NORMAL_MATRIX*NORMAL);}
float h(vec2 v){return fract(sin(dot(v,vec2(127.1,311.7)))*43758.5453);}
void fragment(){
 vec2 projected=abs(n.y)>.5?p.xz:(abs(n.x)>abs(n.z)?p.zy:p.xy);
 vec2 q=projected*.9;vec2 cell=floor(q);vec2 f=fract(q);f=f*f*(3.-2.*f);
 float large=mix(mix(h(cell),h(cell+vec2(1,0)),f.x),mix(h(cell+vec2(0,1)),h(cell+vec2(1,1)),f.x),f.y);
 float patch=(large-.5)*.10;
 float ribs=roof*(.06*sin(p.z*35.)+.025*sin(p.z*70.));
 vec3 weights=pow(abs(n),vec3(6));weights/=max(dot(weights,vec3(1)),.001);
 vec3 wear=texture(wear_texture,p.zy*.16).rgb*weights.x+texture(wear_texture,p.xz*.16).rgb*weights.y+texture(wear_texture,p.xy*.16).rgb*weights.z;
 float weather=clamp(1.+(dot(wear,vec3(.3,.5,.2))-.27)*3.2,.68,1.28);
 float rust=roof*smoothstep(.70,.85,large)*.12;
 ALBEDO=base_color.rgb*(.96+patch+ribs)*mix(1.,weather,.70)-vec3(.0,.03,.04)*rust;
 float mineral=smoothstep(-.005,.025,wear.r-wear.b);
 ALBEDO*=1.-mineral*.16*(1.-roof);
 float peeled=stucco*mineral;
 ALBEDO=mix(ALBEDO,vec3(.40,.37,.32),peeled*.42);
 vec2 roof_uv=roof_axis<.5?vec2(p.z*.38,p.x*.23):vec2(p.x*.38,p.z*.23);
 vec3 zinc=texture(roof_texture,roof_uv).rgb;
 ALBEDO=mix(ALBEDO,zinc*.94,roof);
 ROUGHNESS=1.;SPECULAR=0.;
}





