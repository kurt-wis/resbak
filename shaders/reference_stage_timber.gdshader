shader_type spatial;
render_mode diffuse_lambert,specular_disabled;
uniform sampler2D paint_texture : source_color,repeat_enable,filter_linear_mipmap;
varying vec3 p;
varying vec3 n;
void vertex(){p=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;n=normalize(MODEL_NORMAL_MATRIX*NORMAL);}
void fragment(){
 vec2 uv=abs(n.y)>.5?p.xz:vec2(p.x,p.y);
 vec3 brush=texture(paint_texture,uv*.20).rgb;
 float row=uv.y/.34;
 float seam=1.-smoothstep(.012,.025,min(fract(row),1.-fract(row)));
 float grain=sin(uv.x*18.+sin(uv.y*8.))*.014;
 vec3 timber=mix(vec3(.43,.31,.19),brush,.42)+grain;
 ALBEDO=mix(timber,timber*.61,seam*.66);
 ROUGHNESS=1.;SPECULAR=0.;
}
