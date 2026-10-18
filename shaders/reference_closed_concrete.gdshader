shader_type spatial;
render_mode diffuse_lambert,specular_disabled,cull_disabled;
#include "res://shaders/court_summer.gdshaderinc"
uniform vec4 base_color : source_color;
uniform float roof=0.;
uniform float court_finish=0.;
uniform vec2 court_scale=vec2(.864618,.765034);
uniform vec4 accent_color : source_color=vec4(.36,.61,.57,1.);
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
 float grain=clamp((dot(fine,vec3(.3,.5,.2))-.27)*.8,-.075,.075);
 float weather=clamp((dot(wear,vec3(.3,.5,.2))-.27)*.65,-.065,.055);
 vec2 projection=abs(n.y)>.5?p.xz:(abs(n.x)>abs(n.z)?p.zy:p.xy);
 float brush=(soft_noise(projection*.48)-.5)*.10;
 // Paint grain follows the surface; directional shadows remain the light's job.
 float plaster=(soft_noise(projection*9.0)-.5)*.045;
 float court=step(base_color.g*1.25,base_color.r)*(1.0-stucco)*step(.7,abs(n.y));
 float roller=(soft_noise(vec2(projection.x*.65,projection.y*3.5))-.5)*.065;
 brush+=plaster+court*roller;
 vec3 pigment=base_color.rgb;
 vec2 court_pos=p.xz/court_scale;
 float key_mask=step(15.8,abs(court_pos.x))*step(abs(court_pos.x),21.5)*step(abs(court_pos.y-1.4),2.8);
 float center_mask=1.-smoothstep(1.94,2.,length(court_pos-vec2(-.28,1.4)));
 pigment=mix(pigment,accent_color.rgb,max(key_mask,center_mask*.65)*court_finish);
 // Sun-faded pigment and fine aggregate add texture without painted-on shadows.
 float scuff=smoothstep(.48,.73,soft_noise(projection*3.8))*.035;
 ALBEDO=pigment*(1.015+grain*.7+weather*.65+brush*.7+scuff);
 // Restrained wear belongs to painted walls, not every concrete slab.
 float chipped=stucco*smoothstep(.005,.035,wear.r-wear.b);
 ALBEDO*=1.-chipped*.10;
 vec2 roof_uv=roof_axis<.5?vec2(p.z*.38,p.x*.23):vec2(p.x*.38,p.z*.23);
 ALBEDO=mix(ALBEDO,texture(roof_texture,roof_uv).rgb*.94,roof);
 // Fine aggregate and irregular scuffs cluster in the painted playing lanes.
 float traffic=1.-smoothstep(2.0,7.0,abs(court_pos.y-1.4));
 float worn=smoothstep(.58,.75,summer_noise(vec2(p.x*1.4,p.z*5.0)));
 float aggregate=summer_fine(projection*32.0);
 float speck=smoothstep(.77,.92,aggregate)*.07;
 vec3 concrete=vec3(.49,.48,.43);
 ALBEDO=mix(ALBEDO,concrete,worn*traffic*court_finish*.12*summer_wear);
 ALBEDO*=1.-speck*summer_wear;
 // Plaster repairs have soft irregular edges; dirt gathers at the foot of walls.
 float patch=smoothstep(.67,.78,summer_noise(projection*1.1));
 ALBEDO=mix(ALBEDO,ALBEDO*.94,patch*stucco*summer_wear);
 float foot=(1.-smoothstep(-1.2,-.5,p.y))*stucco;
 ALBEDO*=1.-foot*.075*summer_wear;
 ALBEDO=summer_pigment(ALBEDO,p,n);
 ROUGHNESS=1.;SPECULAR=0.;
}
