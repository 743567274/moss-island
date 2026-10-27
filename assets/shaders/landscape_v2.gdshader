shader_type spatial;
render_mode unshaded,cull_disabled,fog_disabled;
uniform float daylight=1.0;
uniform float cloud=0.0;
void fragment(){
 vec3 pigment=mix(vec3(.39,.65,.59),COLOR.rgb,smoothstep(4.9,6.2,UV.y));
 ALBEDO=mix(vec3(.07,.13,.19),pigment,daylight);
 ALBEDO=mix(ALBEDO,vec3(.44,.52,.50),cloud*daylight*.22);
}
