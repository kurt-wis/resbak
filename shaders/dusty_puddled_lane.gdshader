shader_type spatial;
render_mode diffuse_lambert,specular_disabled;
varying vec3 p;
void vertex(){p=(MODEL_MATRIX*vec4(VERTEX,1)).xyz;}
float h(vec2 v){return fract(sin(dot(v,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 v){vec2 i=floor(v);vec2 f=fract(v);f=f*f*(3.-2.*f);return mix(mix(h(i),h(i+vec2(1,0)),f.x),mix(h(i+vec2(0,1)),h(i+vec2(1,1)),f.x),f.y);}
void fragment(){
 vec2 q=p.xz;
 float patches=noise(q*.7)*.7+noise(q*1.8)*.3;
 float dirt=smoothstep(.40,.67,patches);
 vec3 soil=mix(vec3(.38,.37,.39),vec3(.44,.40,.36),dirt);
 float water=smoothstep(.82,.845,noise(q*.48+vec2(25,7))+noise(q*2.2)*.09);
 vec3 puddle=mix(vec3(.28,.33,.36),vec3(.38,.43,.45),smoothstep(.76,.88,patches));
 float rim=smoothstep(.80,.825,noise(q*.48+vec2(25,7))+noise(q*2.2)*.09)-water;
 vec2 cell=floor(q*3.2);vec2 f=fract(q*3.2)-.5;
 float pebble=(1.-smoothstep(.06,.11,length(f)))*step(.91,h(cell));
 float rut=(1.-smoothstep(.025,.06,abs(sin(q.y*1.25+sin(q.x*.5)*.16))))*dirt*.12;
 ALBEDO=(mix(soil,puddle,water)-vec3(.025)*rim+vec3(.06)*pebble-vec3(rut))*1.5;
 ROUGHNESS=1.;SPECULAR=0.;
}

