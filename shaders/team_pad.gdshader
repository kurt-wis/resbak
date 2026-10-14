shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform vec4 team_color : source_color = vec4(1.0,0.7,0.15,1.0);
void fragment() {
 float radius = length(UV-vec2(0.5));
 float inner = smoothstep(0.305,0.312,radius)*(1.0-smoothstep(0.322,0.330,radius));
 float outer = smoothstep(0.355,0.362,radius)*(1.0-smoothstep(0.378,0.385,radius));
 float aura = exp(-abs(radius-0.366)*55.0)*0.24;
 float fill = (1.0-smoothstep(0.29,0.36,radius))*0.20;
 ALBEDO = mix(team_color.rgb,vec3(1.0,0.92,0.78),max(inner,outer)*0.65);
 ALPHA = clamp(max(inner,outer)*0.9+aura+fill,0.0,1.0);
}
