shader_type spatial;
render_mode diffuse_lambert,specular_disabled;
uniform vec4 base_color : source_color;
uniform float planted_ground = 0.0;
uniform sampler2D grain_texture : source_color,repeat_enable,filter_linear_mipmap;
varying vec3 p;
varying vec3 n;
float hash21(vec2 v){return fract(sin(dot(v,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 q){vec2 c=floor(q);vec2 f=fract(q);f=f*f*(3.-2.*f);return mix(mix(hash21(c),hash21(c+vec2(1,0)),f.x),mix(hash21(c+vec2(0,1)),hash21(c+vec2(1,1)),f.x),f.y);}
void vertex(){p=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;n=normalize(MODEL_NORMAL_MATRIX*NORMAL);}
void fragment(){
 vec2 uv=abs(n.y)>.5?p.xz:(abs(n.x)>abs(n.z)?p.zy:p.xy);
 float grain=dot(texture(grain_texture,uv*.55).rgb,vec3(.3,.5,.2));
 float variation=clamp((grain-.27)*.5,-.055,.055)+(noise(uv*2.0)-.5)*.04;
 vec3 earth=mix(vec3(.40,.46,.31),vec3(.63,.59,.43),smoothstep(.2,.8,noise(p.xz*.23)));
 ALBEDO=mix(base_color.rgb,earth,planted_ground)*(1.+variation);
 ROUGHNESS=1.;SPECULAR=0.;
}
