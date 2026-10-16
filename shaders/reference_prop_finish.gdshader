shader_type spatial;
render_mode diffuse_lambert,specular_disabled;
uniform sampler2D paint_texture : source_color,filter_linear_mipmap;
uniform float rust_frame=0.;
void fragment(){
 vec3 c=texture(paint_texture,UV).rgb;
 float luma=dot(c,vec3(.3,.5,.2));
 c=mix(vec3(luma),c,.80)*.94;
 float blue=step(c.r*1.06,c.b)*step(.12,c.b);
 vec3 brown=vec3(.47,.36,.23)*(luma/.32);
 ALBEDO=mix(c,brown,blue*rust_frame);
 ROUGHNESS=1.;SPECULAR=0.;
}
