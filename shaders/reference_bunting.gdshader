shader_type spatial;
render_mode unshaded,cull_disabled;
uniform vec4 flag_color : source_color;
void fragment(){ALBEDO=flag_color.rgb;}
