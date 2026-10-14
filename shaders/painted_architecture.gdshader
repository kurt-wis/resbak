shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
uniform sampler2D painted_surface : source_color, repeat_enable, filter_linear_mipmap;
uniform vec4 tint : source_color = vec4(.65,.65,.65,1.0);
varying vec3 world_position;
varying vec3 world_normal;
void vertex(){world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);}
void fragment(){
 vec3 weights=pow(abs(world_normal),vec3(6.0)); weights/=max(dot(weights,vec3(1.0)),.001);
 vec3 p=world_position*.23;
 vec3 painted=texture(painted_surface,p.zy).rgb*weights.x+texture(painted_surface,p.xz).rgb*weights.y+texture(painted_surface,p.xy).rgb*weights.z;
 // Preserve cracks, exposed plaster and brushwork rather than clipping their contrast.
 vec3 variation=mix(vec3(1.0),clamp(painted/vec3(.53,.54,.60),vec3(.65),vec3(1.35)),.28);
 float dirt=1.0-.04*exp(-max(world_position.y,0.0)*2.0);
 ALBEDO=pow(tint.rgb,vec3(2.2))*variation*dirt*2.0;
 ROUGHNESS=1.0; SPECULAR=0.0;
}



