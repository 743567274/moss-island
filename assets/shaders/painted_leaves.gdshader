shader_type spatial;
render_mode cull_disabled,diffuse_burley;
uniform sampler2D leaf_map : source_color, filter_linear_mipmap_anisotropic;
uniform float wind=.2;
uniform vec2 wind_direction=vec2(.98,.2);
uniform float wetness=0.0;
uniform float snow_cover=0.0;
uniform float autumn=0.0;
varying vec3 wp;
void vertex(){
 wp=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 float sway=sin(TIME*1.15+wp.x*.6+wp.z*.7)*wind*.10*(1.0-UV.y);
 VERTEX.x+=sway*wind_direction.x;VERTEX.z+=sway*wind_direction.y;
 // Rounded canopy normals retain soft volume across intersecting leaf cards.
 NORMAL=normalize(vec3(VERTEX.x*.2,.7,.5));
}
void fragment(){
 vec4 leaf=texture(leaf_map,UV);
 ALBEDO=leaf.rgb*COLOR.rgb*(1.0-wetness*.10);
 ALBEDO=mix(ALBEDO,vec3(.42,.31,.12),autumn*.08);
 float fleck=smoothstep(.7,.95,leaf.g)*snow_cover*.7;
 ALBEDO=mix(ALBEDO,vec3(.79,.86,.87),fleck);
 ALPHA=leaf.a;
 ALPHA_SCISSOR_THRESHOLD=.48;
 ROUGHNESS=.96;SPECULAR=.1;
 BACKLIGHT=vec3(.09,.13,.05);
}
