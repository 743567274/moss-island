shader_type spatial;
render_mode cull_disabled;
uniform sampler2D atlas : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D grass_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D earth_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D path_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec2 tile=vec2(0.0);
uniform float terrain=0.0;
uniform float soil=0.0;
uniform float path=0.0;
uniform float wetness=0.0;
uniform float snow_cover=0.0;
uniform float daylight=1.0;
uniform float wind=0.0;
uniform float foliage=0.0;
uniform vec2 wind_direction=vec2(1.0,0.0);
uniform bool selected=false;
uniform vec2 selected_center=vec2(0.0);
uniform float shadow_strength=.2;
uniform vec2 shadow_direction=vec2(.5,.5);
varying vec3 wp;
varying vec3 wn;
vec3 painted(vec2 uv,vec2 cell){
 return texture(atlas,(cell+mix(vec2(.018),vec2(.982),fract(uv)))/vec2(4.0,2.0)).rgb;
}
vec3 lawn(vec2 uv){
 return texture(grass_map,uv*.52).rgb*.86+vec3(.025,.035,.012);
}
void vertex(){
 wp=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 float sway=sin(TIME*1.3+wp.x*.7+wp.z*.4)*foliage*wind*.045;
 VERTEX.xz+=wind_direction*sway;
 wp=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 wn=normalize(MODEL_NORMAL_MATRIX*NORMAL);
}
void fragment(){

 vec3 pigment=painted(UV,tile);
 if(terrain>.5){

  pigment=lawn(wp.xz*.16);
  vec3 bank=painted(wp.xz*.25+vec2(0.0,wp.y),vec2(1.0,1.0))*.72;
  pigment=mix(bank,pigment,smoothstep(.30,.44,wp.y));
  vec2 d=wp.xz-vec2(-8.7,-4.7)-shadow_direction*1.2;
  float footprint=1.0-smoothstep(.9,1.7,max(abs(d.x)/3.1,abs(d.y)/2.0));
  pigment*=1.0-footprint*shadow_strength;
 }
 if(soil>.5){
  vec2 q=abs(UV-.5)*2.0;
  float edge=max(q.x,q.y);
  float grain=texture(earth_map,wp.xz*.4).r;
  vec3 mud=painted(wp.xz*.45,vec2(1.0,1.0))*(.87+grain*.2);
  float lip=smoothstep(.70,.97,edge+(grain-.4)*.12);
  pigment=mix(mud,lawn(wp.xz*.19)*.84,lip);
  float furrow=sin(UV.y*31.4159+sin(UV.x*9.0)*.4);
  pigment*=.95+.05*furrow*(1.0-lip);
  if(selected){
   vec2 p=abs((wp.xz-selected_center)/vec2(.89,.76));
   float r=pow(pow(p.x,4.0)+pow(p.y,4.0),.25);
   float line=smoothstep(.83,.87,r)*(1.0-smoothstep(.9,.95,r));
   pigment=mix(pigment,vec3(.65,.43,.12),line*.7);
  }
 }
 if(path>.5) pigment=texture(path_map,wp.xz*.27).rgb;
 ALBEDO=pigment*COLOR.rgb;
 ALBEDO*=1.0-wetness*.18;
 ALBEDO=mix(ALBEDO,vec3(.78,.85,.87),snow_cover*smoothstep(.25,.85,wn.y));
 ROUGHNESS=mix(.98,.58,wetness*max(wn.y,0.0));
 SPECULAR=.12;
}
