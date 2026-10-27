shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_never;
uniform float amount=0.0;
uniform float snow_mode=0.0;
uniform float wind=.2;
uniform vec2 wind_direction=vec2(.98,.2);
uniform float height=9.0;
uniform float speed=1.0;
varying float enabled;
varying float tint;
void vertex(){
 float seed=INSTANCE_CUSTOM.x;
 float age=fract(TIME*speed*(.85+seed*.3)/height+seed);
 float y=(1.0-age)*height;
 vec3 offset=vec3(wind_direction.x*wind*y*.15,y,wind_direction.y*wind*y*.15);
 offset.x+=snow_mode*(sin(TIME*.8+seed*37.0)*.38+sin(TIME*1.6+seed*19.0)*.12)*sin(age*3.14159);
 offset.z+=snow_mode*cos(TIME*.6+seed*51.0)*.25*sin(age*3.14159);
 float turn=TIME*.4*seed*snow_mode;
 vec2 rotated=mat2(vec2(cos(turn),-sin(turn)),vec2(sin(turn),cos(turn)))*VERTEX.xy;
 VERTEX.xy=mix(VERTEX.xy,rotated,snow_mode);
 VERTEX+=offset;
 enabled=step(seed,amount);
 tint=.65+seed*.35;
}
void fragment(){
 if(enabled<.5)discard;
 float shape=mix(1.0,1.0-smoothstep(.25,.5,length(UV-.5)),snow_mode);
 ALBEDO=mix(vec3(.55,.72,.80),vec3(.9,.94,.94),snow_mode)*tint;
 ALPHA=amount*shape*.65;
}
