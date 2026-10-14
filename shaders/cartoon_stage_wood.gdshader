shader_type spatial;
render_mode diffuse_lambert,specular_disabled;
varying vec3 p;
varying vec3 n;
void vertex(){p=(MODEL_MATRIX*vec4(VERTEX,1)).xyz;n=normalize(MODEL_NORMAL_MATRIX*NORMAL);}
float hash(float v){return fract(sin(v*127.1)*43758.5453);}
void fragment(){
 vec2 uv=abs(n.y)>.5?p.xz:p.xy;
 float row=floor(uv.y*2.2);float across=fract(uv.y*2.2);
 float edge=smoothstep(.025,.065,across)*(1.-smoothstep(.94,.98,across));
 vec3 plank=mix(vec3(.40,.28,.18),vec3(.50,.37,.25),hash(row));
 float flowing=sin(uv.x*3.6+sin(uv.y*8.)*.9);
 float grain=1.-smoothstep(.055,.10,abs(flowing-.5));
 float end=1.-smoothstep(.018,.035,abs(fract(uv.x/2.8+hash(row))-.5));
 float scuff=smoothstep(.93,.99,sin(uv.x*4.+row*12.))*smoothstep(.7,.9,across);
 ALBEDO=mix(vec3(.20,.14,.11),plank,edge)*(1.-grain*.12-end*.15)+vec3(.055,.045,.03)*scuff;
 ALBEDO*=1.45;
 ROUGHNESS=1.;SPECULAR=0.;
}

