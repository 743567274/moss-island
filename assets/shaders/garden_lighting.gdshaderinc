uniform vec2 map_size=vec2(32.0,18.0);
uniform vec2 light_direction=vec2(-.7,-.7);
uniform vec4 tree_shadows[6];
uniform vec4 local_lamps[4];
uniform float local_lamp_energy[4];
uniform vec4 local_lamp_style[4];
uniform vec4 local_lamp_color[4];
float garden_lamp_weight(vec2 uv,int i,float day){
 if(local_lamp_energy[i]<=0.0)return 0.0;
 vec4 style=local_lamp_style[i];
 float active=style.w>.5?1.0-day:1.0;
 vec2 direction=vec2(cos(style.y),sin(style.y));
 float pool=1.0;
 if(style.x>1.5){
  pool=clamp(.85+.35*dot((uv-vec2(.5))*vec2(1.0,.5625),direction),.45,1.2);
 }else{
  vec2 delta=uv-local_lamps[i].xy;
  vec2 distance=delta/max(local_lamps[i].zw,vec2(.001));
  pool=exp(-dot(distance,distance)*1.4);
  if(style.x>.5){
   vec2 projected=delta*map_size;
   float cone=dot(normalize(projected+vec2(.000001)),direction);
   pool*=smoothstep(style.z,min(1.0,style.z+.06),cone);
  }
 }
 float flicker=local_lamp_color[i].w>.5?(.98+.02*sin(TIME*1.3+float(i))):1.0;
 return pool*local_lamp_energy[i]*active*flicker;
}
vec3 garden_lamp_glow(vec2 uv,float day){
 vec3 glow=vec3(0.0);
 for(int i=0;i<4;i++)glow+=local_lamp_color[i].rgb*garden_lamp_weight(uv,i,day);
 return glow;
}
float garden_shadow(vec2 uv){
 float result=0.0;
 vec2 direction=normalize(light_direction+vec2(.0001));
 for(int i=0;i<6;i++){
  if(tree_shadows[i].w<.01)continue;
  vec2 p=(uv-tree_shadows[i].xy)*map_size-direction*tree_shadows[i].w*.25;
  vec2 local=vec2(dot(p,direction),dot(p,vec2(-direction.y,direction.x)));
  vec2 radius=vec2(tree_shadows[i].w*.42,tree_shadows[i].z);
  if(abs(local.x)>=radius.x || abs(local.y)>=radius.y)continue;
  float d=length(local/max(radius,vec2(.01)));
  result=max(result,(1.0-smoothstep(.5,1.0,d))*.34);
 }
 return result;
}
vec3 garden_color(vec3 pigment,vec2 uv,vec3 normal,float day,float moon,float clouds){
 vec3 light=normalize(vec3(-light_direction.x,.9,-light_direction.y));
 float direct=max(0.0,dot(normalize(normal),light));
 vec3 night=pigment*vec3(.14,.24,.40)*(.75+moon*1.5)*(.65+direct*.65);
 vec3 color=night;
 if(day>0.0){
  vec3 sunny=pigment*(vec3(.68,.76,.83)+vec3(.47,.33,.13)*direct);
  sunny*=1.0-garden_shadow(uv)*(1.0-clouds*.85);
  vec3 diffuse=pigment*vec3(.48,.56,.67);
  vec3 daytime=mix(sunny,diffuse,smoothstep(.12,.85,clouds));
  color=mix(night,daytime,day);
 }
 color+=pigment*garden_lamp_glow(uv,day);
 return color;
}
