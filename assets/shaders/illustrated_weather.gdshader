shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_never,fog_disabled;
uniform float amount=0.0;
uniform float snow_mode=0.0;
uniform float wind=.2;
uniform vec2 wind_direction=vec2(.98,.2);
uniform float speed=1.0;
uniform float height=9.0;
uniform float daylight=1.0;
varying float enabled;
varying float rain_depth;
varying float rain_fade;
float rain_hash(vec2 p){
 return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);
}
void vertex(){
 float seed=INSTANCE_CUSTOM.x;
 if(snow_mode<.5){
  // Each drop falls on a continuous trajectory, then respawns at a new x.
  // Size/depth and velocity vary independently of the density threshold.
  rain_depth=mix(.65,1.35,INSTANCE_CUSTOM.z);
  float clock=TIME*speed*mix(.85,1.30,INSTANCE_CUSTOM.z)/22.0+INSTANCE_CUSTOM.y;
  float cycle=floor(clock);
  float age=fract(clock);
  float spawn=rain_hash(vec2(seed*197.0,cycle));
  float slope=wind*wind_direction.x*.24;
  vec2 center=vec2((spawn-.5)*36.0+slope*(age-.5)*22.0,(age-.5)*22.0);
  vec2 v=VERTEX.xy;
  v.x*=mix(.70,1.15,amount)*rain_depth;
  v.y*=mix(.65,1.50,amount)*rain_depth;
  v.x+=v.y*slope;
  POSITION=PROJECTION_MATRIX*VIEW_MATRIX*vec4(center.x+v.x,2.0,center.y+v.y,1.0);
  enabled=step(seed,amount);
  rain_fade=smoothstep(0.0,.035,age)*(1.0-smoothstep(.965,1.0,age));
 }else{
 float age=fract(TIME*mix(speed*.038,.035+seed*.025,snow_mode)+seed);
 vec2 p=vec2((INSTANCE_CUSTOM.y-.5)*36.0,(age-.5)*22.0);
 p.x+=sin(TIME*.75+seed*31.0)*snow_mode*.42+wind*wind_direction.x*(age-.5)*2.0;
 vec2 v=VERTEX.xy;
 float size=mix(.68,1.32,amount);
 v.y*=mix(.85+amount*.45,size,snow_mode);
 v.x*=mix(.75+amount*.55,size,snow_mode);
 v.x+=v.y*(.12+wind*.12)*(1.0-snow_mode);
 float turn=snow_mode*TIME*.3;
 v=mat2(vec2(cos(turn),-sin(turn)),vec2(sin(turn),cos(turn)))*v;
 POSITION=PROJECTION_MATRIX*VIEW_MATRIX*vec4(p.x+v.x,2.0,p.y+v.y,1.0);
 enabled=step(seed,amount);
 rain_depth=1.0;
 rain_fade=1.0;
 }
}
void fragment(){
 if(enabled<.5)discard;
 if(snow_mode<.5){
  // Soft, tapered motion streaks rather than uniformly filled rectangles.
  float along=UV.y;
  float taper=mix(.30,1.0,smoothstep(0.0,.75,along));
  float edge=abs(UV.x-.5)/taper;
  float width=1.0-smoothstep(.08,.50,edge);
  float ends=smoothstep(0.0,.16,along)*(1.0-smoothstep(.85,1.0,along));
  ALBEDO=mix(vec3(.40,.53,.67),vec3(.77,.83,.86),daylight);
  ALPHA=width*ends*rain_fade*mix(.24,.48,clamp(rain_depth-.4,0.0,1.0));
 }else{
 float shape=mix(1.0,1.0-smoothstep(.23,.5,length(UV-.5)),snow_mode);
 ALBEDO=mix(vec3(.60,.74,.82),vec3(.95,.97,.98),snow_mode);
 ALPHA=mix(.58,.78,snow_mode)*shape;
 }
}
