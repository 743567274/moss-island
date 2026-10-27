shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_never;
uniform float rain=0.0;
void fragment(){
 float age=fract(TIME*1.25+COLOR.r*11.0);
 float d=length(UV-.5);
 float ring=(1.0-smoothstep(.018,.038,abs(d-age*.46)))*(1.0-age);
 ALBEDO=vec3(.62,.79,.77);
 ALPHA=ring*rain*.55;
}
