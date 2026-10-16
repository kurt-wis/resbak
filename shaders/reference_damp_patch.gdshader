shader_type spatial;
render_mode unshaded,cull_disabled;
varying vec3 p;
void vertex(){p=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;}
void fragment(){
 float brush=.008*sin(p.x*2.2+p.z*1.4);
 ALBEDO=vec3(.095,.115,.115)+brush;
 ROUGHNESS=1.;SPECULAR=0.;
}
