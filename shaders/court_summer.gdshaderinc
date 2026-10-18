// Shared surface detail, opt-in per court instance. No color LUT or baked shadows.
uniform float summer_wear = 0.0;
float summer_hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float summer_noise(vec2 p) {
 vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(summer_hash(i),summer_hash(i+vec2(1,0)),f.x),mix(summer_hash(i+vec2(0,1)),summer_hash(i+vec2(1,1)),f.x),f.y);
}
float summer_fine(vec2 p) {
 float footprint=max(length(dFdx(p)),length(dFdy(p)));
 return mix(summer_noise(p),.5,smoothstep(.15,.45,footprint));
}
vec3 summer_pigment(vec3 c, vec3 world, vec3 normal) {
 float l=dot(c,vec3(.299,.587,.114));
 // Keep charcoal and team/prop pigments distinct, soften the exposed paint saturation.
 vec3 faded=mix(vec3(l),c,.94);
 float exposed=smoothstep(-.1,.8,normal.y);
 faded=mix(faded,vec3(.72,.69,.61),exposed*.035);
 float pores=(summer_fine(world.xz*28.0)-.5)*.022;
 faded*=1.-smoothstep(.65,.95,l)*.14;
 return mix(c,faded+pores,summer_wear);
}
