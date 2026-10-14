shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_never;
uniform vec4 team_color : source_color;
void fragment(){
 float scan=step(.88,fract(UV.y*26.0-TIME*.25));
 ALBEDO=team_color.rgb;
 EMISSION=team_color.rgb*.4;
 ALPHA=.09+scan*.13;
}
