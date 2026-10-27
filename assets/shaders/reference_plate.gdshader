shader_type spatial;
render_mode unshaded,cull_disabled,fog_disabled;
uniform sampler2D clean_plate : source_color,filter_linear_mipmap;
uniform sampler2D night_plate : source_color,filter_linear_mipmap;
uniform sampler2D willow_clean_day : source_color,filter_linear_mipmap,repeat_disable;
uniform sampler2D willow_clean_night : source_color,filter_linear_mipmap,repeat_disable;
uniform bool replace_willow=false;
uniform vec4 willow_clean_rect=vec4(.43,.265,.585,.53);
uniform vec4 willow_root_shadow=vec4(.505,.514,.016,.008);
uniform float willow_shadow_strength=.20;
uniform bool has_night_plate=false;
uniform sampler2D companion_layer : source_color,filter_linear_mipmap;
uniform float daylight=1.0;
uniform float moonlight=0.0;
uniform float cloud=0.0;
uniform float fog_amount=0.0;
uniform float rain=0.0;
uniform float wind=.2;
uniform vec2 wind_direction=vec2(1.0,0.0);
uniform float wetness=0.0;
uniform float snow_cover=0.0;
uniform float ice=0.0;
uniform bool companion=false;
uniform vec2 water_points[8];
uniform float water_widths[8];
uniform int water_count=7;
uniform bool has_map_water=false;
uniform sampler2D map_water_mask : filter_linear,repeat_disable;
uniform vec2 map_water_feather=vec2(.006);
uniform float map_water_angle=0.0;
uniform float map_water_speed=1.0;
uniform vec4 water_bounds=vec4(0.0,0.0,1.0,1.0);
uniform vec4 bridge_exclusion=vec4(.37,.49,.515,.625);
uniform vec4 lamps[4];
uniform float lamp_energy[4];
uniform float lamp_lantern[4];
#include "res://assets/shaders/garden_lighting.gdshaderinc"
float rect(vec2 uv,vec2 lo,vec2 hi){
 vec2 a=smoothstep(lo,lo+vec2(.004),uv);
 vec2 b=1.0-smoothstep(hi-vec2(.004),hi,uv);
 return a.x*a.y*b.x*b.y;
}
float water_mask(vec2 p){
 if(has_map_water){
  float value=texture(map_water_mask,p).r*.4;
  value+=(texture(map_water_mask,p+vec2(map_water_feather.x,0)).r+texture(map_water_mask,p-vec2(map_water_feather.x,0)).r+texture(map_water_mask,p+vec2(0,map_water_feather.y)).r+texture(map_water_mask,p-vec2(0,map_water_feather.y)).r)*.15;
  return smoothstep(.03,.97,value);
 }
 if(p.x<water_bounds.x || p.y<water_bounds.y || p.x>water_bounds.z || p.y>water_bounds.w)return 0.0;
 float result=0.0;
 for(int i=0;i<7;i++){
  if(i>=water_count-1)break;
  vec2 a=water_points[i],b=water_points[i+1];
  float t=clamp(dot(p-a,b-a)/max(.00001,dot(b-a,b-a)),0.0,1.0);
  vec2 delta=p-mix(a,b,t);
  float width=mix(water_widths[i],water_widths[i+1],t);
  if(dot(delta,delta)>=width*width)continue;
  float distance=length(delta);
  result=max(result,1.0-smoothstep(width*.72,width,distance));
 }
 return result*(1.0-rect(p,bridge_exclusion.xy,bridge_exclusion.zw));
}
void fragment(){
 vec2 p=UV;
 // The river path lies behind the painted willow. Exclude its silhouette
 // from both water distortion and specular bands, including the rooted trunk.
 float canopy=replace_willow?0.0:1.0-smoothstep(.92,1.04,length((p-vec2(.507,.387))/vec2(.079,.125)));
 float rooted_trunk=replace_willow?0.0:rect(p,vec2(.477,.408),vec2(.535,.534));
 float tree_cover=max(canopy,rooted_trunk);
 float river=water_mask(p)*(1.0-tree_cover);
 vec2 sample_uv=p;
 // Identify foliage from the day plate so the same mask remains stable at
 // night. Brown branches and the lower trunk never receive wind displacement.
 float foliage=0.0;
 if(canopy>.00001){
  vec3 reference=texture(clean_plate,p).rgb;
  foliage=smoothstep(.012,.065,reference.g-reference.r)*smoothstep(.005,.055,reference.g-reference.b);
 }
 float trunk_anchor=rect(p,vec2(.491,.407),vec2(.523,.535));
 float branch_weight=1.0-smoothstep(.405,.515,p.y);
 float leaf_motion=canopy*foliage*(1.0-trunk_anchor)*branch_weight;
 float breeze=sin(TIME*.78)+.22*sin(TIME*1.19+p.x*24.0+p.y*9.0);
 sample_uv.x+=breeze*(.00035+clamp(wind,0.0,1.0)*.0025)*leaf_motion*(wind_direction.x*.75+wind_direction.y*.25);
 float wind_wave=.35+clamp(wind,0.0,1.0)*2.0;
 float water_clock=TIME*(has_map_water?map_water_speed:1.0);
 vec2 flow=has_map_water?vec2(cos(map_water_angle),sin(map_water_angle)):vec2(1.0,0.0);
 float motion_scale=has_map_water?min(1.0,map_water_speed):1.0;
 vec2 movement=vec2(sin(p.y*110.0+water_clock*(.6+wind))*.0018,sin(p.x*87.0-water_clock*(.45+wind*.8))*.0012);
 movement=vec2(movement.x*flow.x-movement.y*flow.y,movement.x*flow.y+movement.y*flow.x);
 sample_uv+=movement*river*wind_wave*motion_scale;
 vec3 pigment=vec3(0.0);
 float clean_mask=replace_willow?rect(p,willow_clean_rect.xy,willow_clean_rect.zw):0.0;
 vec2 patch_uv=clamp((sample_uv-willow_clean_rect.xy)/(willow_clean_rect.zw-willow_clean_rect.xy),vec2(0.0),vec2(1.0));
 if(daylight>0.0 || !has_night_plate){
  pigment=texture(clean_plate,sample_uv).rgb;
  if(clean_mask>0.0)pigment=mix(pigment,texture(willow_clean_day,patch_uv).rgb,clean_mask);
  if(river>0.0){
   float wave=pow(max(0.0,sin(p.x*110.0+p.y*255.0-water_clock*1.25)),18.0);
   float second=pow(max(0.0,sin(p.x*75.0-p.y*181.0+water_clock*.8)),25.0);
   pigment+=vec3(.032,.049,.052)*(wave+second*.55)*river*wind_wave;
  }
 }
 vec3 night=vec3(0.0);
 if(daylight<1.0){
  vec3 painted_night=texture(night_plate,sample_uv).rgb;
  if(clean_mask>0.0)painted_night=mix(painted_night,texture(willow_clean_night,patch_uv).rgb,clean_mask);
  night=has_night_plate?painted_night*(.72+moonlight*.9):(garden_color(pigment,p,vec3(0,1,0),0.0,moonlight,cloud)-pigment*garden_lamp_glow(p,0.0));
  night*=1.0-cloud*.22;
 }
 vec3 day=vec3(0.0);
 if(daylight>0.0)day=garden_color(pigment,p,vec3(0,1,0),1.0,moonlight,cloud)-pigment*garden_lamp_glow(p,1.0);
 vec3 color=mix(night,day,daylight);
 if(replace_willow){
  vec2 root_delta=(p-willow_root_shadow.xy)/willow_root_shadow.zw;
  if(abs(root_delta.x)<2.0 && abs(root_delta.y)<2.0)color*=1.0-willow_shadow_strength*exp(-dot(root_delta,root_delta)*2.6);
 }
 color*=1.0-wetness*.05;
 float sky=1.0-smoothstep(.18,.35,p.y);
 color=mix(color,vec3(.19,.23,.28),cloud*daylight*sky*.30);
 color+=vec3(.011,.021,.04)*sky*(1.0-daylight)*moonlight;
 float fog=smoothstep(.2,.85,fog_amount);
 float haze=fog*(.38+.38*(1.0-p.y)+sin(p.x*8.0+p.y*13.0+TIME*.09)*.025);
 color=mix(color,mix(vec3(.11,.16,.23),vec3(.68,.75,.71),daylight),haze);
 color+=garden_lamp_glow(p,daylight);
 ALBEDO=color;
}
