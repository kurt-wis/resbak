shader_type spatial;
render_mode diffuse_lambert,specular_disabled,cull_disabled;
uniform vec4 paint_color : source_color;
float stroke(vec2 p,vec2 a,vec2 b,float width){vec2 v=b-a;float t=clamp(dot(p-a,v)/dot(v,v),0.,1.);return 1.-smoothstep(width,width+.012,length(p-a-v*t));}
void fragment(){
 vec2 p=UV;
 float ink=stroke(p,vec2(.08,.75),vec2(.28,.22),.024);
 ink=max(ink,stroke(p,vec2(.28,.22),vec2(.39,.68),.024));
 ink=max(ink,stroke(p,vec2(.12,.57),vec2(.36,.5),.023));
 ink=max(ink,stroke(p,vec2(.42,.71),vec2(.59,.28),.023));
 ink=max(ink,stroke(p,vec2(.59,.28),vec2(.72,.67),.023));
 ink=max(ink,stroke(p,vec2(.46,.58),vec2(.69,.51),.023));
 ink=max(ink,stroke(p,vec2(.76,.27),vec2(.84,.69),.025));
 ink=max(ink,stroke(p,vec2(.84,.69),vec2(.94,.29),.025));
 ink=max(ink,stroke(p,vec2(.09,.84),vec2(.91,.75),.016));
 float fleck=fract(sin(dot(floor(p*155.),vec2(127.,311.)))*43758.);
 ALBEDO=paint_color.rgb;ALPHA=ink*(.65+fleck*.2);ROUGHNESS=1.;SPECULAR=0.;
}
