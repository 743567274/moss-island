shader_type spatial;
render_mode cull_disabled;
uniform sampler2D brush : repeat_enable, filter_linear;
uniform float wetness=0.0;
uniform float snow_cover=0.0;
uniform float daylight=1.0;
uniform float wind=0.1;
uniform vec2 wind_direction=vec2(.98,.2);
uniform float autumn=0.0;
uniform float foliage=0.0;
uniform float terrain=0.0;
uniform float soil=0.0;
uniform bool selected=false;
uniform vec2 selected_center=vec2(0.0);
uniform vec2 shadow_direction=vec2(.6,.4);
uniform float shadow_strength=.3;
varying vec3 wp;
varying vec3 wn;
void vertex(){
 wp=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 float bend=sin(TIME*1.5+wp.x*.6+wp.z*.4)*wind*.055*foliage*clamp(wp.y-.4,0.0,2.0);
 VERTEX.x+=bend*wind_direction.x; VERTEX.z+=bend*wind_direction.y;
 wp=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 wn=normalize(MODEL_NORMAL_MATRIX*NORMAL);
}
void fragment(){
 float wash=texture(brush,wp.xz*.14+wp.xy*.06).r;
 vec3 pigment=pow(COLOR.rgb,vec3(2.2));
 ALBEDO=pigment*(.93+.12*wash);
 ALBEDO=mix(ALBEDO,vec3(.32,.24,.10),autumn*foliage*.18);
 float up=max(wn.y,0.0);
 if(terrain>.5){
  vec2 shadow=wp.xz-vec2(-3.4,-3.5)-shadow_direction*1.3;
  float footprint=1.0-smoothstep(1.0,1.7,max(abs(shadow.x)/3.1,abs(shadow.y)/2.0));
  ALBEDO*=1.0-footprint*shadow_strength;
 }
 ALBEDO*=1.0-wetness*.17*(1.0-foliage*.4);
 float snow=snow_cover*smoothstep(.2,.85,up)*COLOR.a;
 ALBEDO=mix(ALBEDO,vec3(.82,.88,.89),snow);
 if(soil>.5 && selected){
  vec2 local=abs((wp.xz-selected_center)/vec2(.89,.76));
  float r=pow(pow(local.x,4.0)+pow(local.y,4.0),.25);
  float edge=smoothstep(.82,.86,r)*(1.0-smoothstep(.89,.94,r));
  ALBEDO=mix(ALBEDO,vec3(.75,.64,.28),edge*.6);
 }
 ROUGHNESS=mix(.96,.45,wetness*up*(1.0-foliage*.65));
 SPECULAR=.15+wetness*.15;
 EMISSION=pigment*(1.0-COLOR.a)*(1.0-daylight)*1.2;
}
