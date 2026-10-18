shader_type spatial;
render_mode unshaded,cull_disabled;
#include "res://shaders/court_summer.gdshaderinc"
uniform float summer_breeze = 0.;
void vertex(){VERTEX.z+=sin(TIME*1.6+VERTEX.x*2.1)*.025*summer_breeze*(1.-UV.y);}
uniform vec4 flag_color : source_color;
void fragment(){ALBEDO=mix(flag_color.rgb,mix(vec3(dot(flag_color.rgb,vec3(.3,.6,.1))),flag_color.rgb,.90),summer_wear);}
