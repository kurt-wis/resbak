shader_type spatial;
render_mode diffuse_lambert,specular_disabled;
#include "res://shaders/court_summer.gdshaderinc"
varying vec3 summer_world;
varying vec3 summer_normal;
void vertex(){summer_world=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;summer_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);}
uniform sampler2D paint_texture : source_color,filter_linear_mipmap;
uniform float rust_frame=0.;
void fragment(){
 vec3 c=texture(paint_texture,UV).rgb;
 float luma=dot(c,vec3(.3,.5,.2));
 c=mix(vec3(luma),c,1.02)*1.01;
 float blue=step(c.r*1.06,c.b)*step(.12,c.b);
 vec3 brown=vec3(.47,.36,.23)*(luma/.32);
 ALBEDO=mix(c,brown,blue*rust_frame);
 ALBEDO=summer_pigment(ALBEDO,summer_world,summer_normal);
 // Restrained handling wear; retain the authored wood/plastic/tire texture.
 float handling=summer_noise(summer_world.xz*6.0);
 ALBEDO*=1.-smoothstep(.7,.85,handling)*.045*summer_wear;
 ROUGHNESS=1.;SPECULAR=0.;
}
