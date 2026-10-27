shader_type spatial;
render_mode unshaded,cull_disabled,fog_disabled;
uniform float daylight=1.0;
uniform float cloud=0.0;
uniform float moon_visibility=0.0;
void fragment(){
 float h=smoothstep(.0,1.0,UV.y);
 vec3 day=mix(vec3(.71,.81,.78),vec3(.39,.64,.73),1.0-h);
 vec3 night=mix(vec3(.035,.065,.12),vec3(.075,.12,.19),h);
 vec3 overcast=mix(vec3(.58,.65,.68),vec3(.77,.80,.78),h);
 ALBEDO=mix(night,mix(day,overcast,cloud*.75),daylight);
 vec2 cell=floor(UV*vec2(420.0,150.0));
 float star=step(.998,fract(sin(dot(cell,vec2(12.9898,78.233)))*43758.5453));
 ALBEDO+=star*.35*(1.0-daylight)*(1.0-cloud)*(1.0-h);
 float moon=1.0-smoothstep(.0,.004,length((UV-vec2(.62,.72))*vec2(2.0,1.0)));
 ALBEDO+=vec3(.7,.76,.8)*moon*moon_visibility*(1.0-daylight)*(1.0-cloud*.8);
}
