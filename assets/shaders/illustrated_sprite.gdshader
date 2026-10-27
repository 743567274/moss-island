shader_type spatial;
render_mode unshaded,cull_disabled,fog_disabled;
uniform sampler2D sprite : source_color,filter_linear_mipmap,repeat_disable;
uniform sampler2D night_sprite : source_color,filter_linear_mipmap,repeat_disable;
uniform bool has_fixture_night=false;
uniform float fixture_night_brightness=.55;
uniform sampler2D emission_mask : filter_linear,repeat_disable;
uniform bool has_emission_mask=false;
uniform bool fixture_enabled=true;
uniform bool fixture_night_only=true;
uniform vec4 region=vec4(0.0,0.0,1.0,1.0);
uniform float daylight=1.0;
uniform float opacity=1.0;
uniform float moonlight=0.0;
uniform float cloud=0.0;
uniform float fog_amount=0.0;
uniform float wind=.2;
uniform vec2 wind_direction=vec2(1.0,0.0);
uniform float health=0.0;
uniform float phase=0.0;
uniform float sway=.009;
uniform float wind_response=4.8;
uniform float sprite_canvas_scale=1.0;
uniform float sprite_rotation=0.0;
uniform bool foliage_only=false;
uniform int environment_motion=0;
uniform bool soft_atmosphere=false;
uniform float cloud_cycle=0.0;
uniform sampler2D water_mask : filter_linear,repeat_disable;
uniform bool has_water_mask=false;
uniform bool world_water_mask=false;
uniform vec2 water_feather=vec2(.006);
uniform float water_angle=0.0;
uniform float water_speed=1.0;
uniform float rain=0.0;
uniform bool light_source=false;
uniform float day_exposure=1.0;
uniform bool crop_style=false;
uniform float style_saturation=.90;
uniform float style_contrast=.94;
uniform float texture_softness=.22;
uniform float paper_grain=.012;
uniform float phase_variation=.70;
uniform float root_detail=0.0;
uniform float root_anchor=.94;
uniform vec2 sprite_world_size=vec2(1.0);
uniform vec2 soil_center=vec2(.5);
uniform vec2 soil_world_size=vec2(2.0);
uniform float soil_rotation=0.0;
uniform sampler2D ground_soil : source_color,filter_linear_mipmap,repeat_disable;
uniform vec4 ground_soil_region=vec4(0.0,0.0,1.0,1.0);
uniform sampler2D ground_day : source_color,filter_linear_mipmap,repeat_disable;
uniform sampler2D ground_night : source_color,filter_linear_mipmap,repeat_disable;
#include "res://assets/shaders/garden_lighting.gdshaderinc"
#include "res://assets/shaders/garden_painterly.gdshaderinc"
varying vec2 world_uv;
varying float individual_phase;
varying float individual_pigment;
varying vec2 art_uv;
float water_coverage(vec2 p){
 if(!has_water_mask)return texture(sprite,region.xy+p*region.zw).a;
 vec2 q=world_water_mask?world_uv+(p-art_uv)*sprite_world_size/map_size:p;
 float value=texture(water_mask,q).r*.4;
 value+=(texture(water_mask,q+vec2(water_feather.x,0)).r+texture(water_mask,q-vec2(water_feather.x,0)).r+texture(water_mask,q+vec2(0,water_feather.y)).r+texture(water_mask,q-vec2(0,water_feather.y)).r)*.15;
 return smoothstep(.03,.97,value)*texture(sprite,region.xy+p*region.zw).a;
}
void vertex(){
 art_uv=(UV-vec2(.5))*sprite_canvas_scale+vec2(.5);
 if(environment_motion==1){
  // Translate the whole image horizontally. A long, fixed travel path keeps
  // clouds distinct from rooted foliage sway and avoids vertical bobbing.
  float cycle=fract(cloud_cycle+phase*.15915494);
  float leg=1.0-abs(cycle*2.0-1.0);
  float travel=leg*leg*(3.0-2.0*leg);
  float shift=(travel-.5)*8.0;
  VERTEX.x+=shift*cos(sprite_rotation);
  VERTEX.z-=shift*sin(sprite_rotation);
 }
 individual_phase=crop_style?(INSTANCE_CUSTOM.r-.5)*phase_variation:0.0;
 individual_pigment=crop_style?mix(.99,1.01,INSTANCE_CUSTOM.g):1.0;
 if(crop_style && sway>0.0){
  float strength=clamp(wind,0.0,1.0);
  vec2 direction=normalize(vec2(wind_direction.x,wind_direction.y*.35)+vec2(.0001,0.0));
  direction=vec2(direction.x*cos(sprite_rotation)+direction.y*sin(sprite_rotation),-direction.x*sin(sprite_rotation)+direction.y*cos(sprite_rotation));
  float flex=pow(clamp((root_anchor-art_uv.y)/max(root_anchor,.01),0.0,1.0),1.65);
  float motion=sin(TIME*1.15+phase+individual_phase)+strength*.22*sin(TIME*2.6+phase*1.7+individual_phase);
  float bend=sprite_world_size.y*sway*wind_response*strength*(.55+.45*strength)*flex*motion;
  VERTEX.x+=bend*direction.x;
  VERTEX.z+=bend*direction.y;
 }
 world_uv=(MODEL_MATRIX*vec4(VERTEX,1.0)).xz/map_size+vec2(.5);
}
void fragment(){
 vec2 local=art_uv;
 float water=0.0;
 if(environment_motion==2){
  water=water_coverage(clamp(art_uv,vec2(0.0),vec2(1.0)));
  float inset=smoothstep(0.0,.12,art_uv.x)*smoothstep(0.0,.12,art_uv.y)*smoothstep(0.0,.12,1.0-art_uv.x)*smoothstep(0.0,.12,1.0-art_uv.y);
  vec2 direction=vec2(cos(water_angle),sin(water_angle));
  float aspect=max(.01,sprite_world_size.x/max(.01,sprite_world_size.y));
  vec2 flow=normalize(direction*vec2(1.0/aspect,1.0));
  float phase_flow=dot(art_uv*vec2(aspect,1.0),direction)*35.0-TIME*water_speed;
  local+=(flow*sin(phase_flow)+vec2(-flow.y,flow.x)*cos(phase_flow*.73))*.003*(.25+wind)*inset*water*min(1.0,water_speed);
  if(has_water_mask && water_coverage(clamp(local,vec2(0.0),vec2(1.0)))<.1)local=art_uv;
 }
 if(foliage_only){
  vec3 leaf=texture(sprite,region.xy+clamp(art_uv,vec2(0.0),vec2(1.0))*region.zw).rgb;
  float green=smoothstep(.003,.028,leaf.g-leaf.r)*smoothstep(.003,.035,leaf.g-leaf.b);
  float weight=green*(.55+.45*clamp(art_uv.y,0.0,1.0))*(1.0-smoothstep(.88,.97,art_uv.y));
  float strength=clamp(wind,0.0,1.0);
  float movement=sin(TIME*1.12+phase+art_uv.x*4.0)+strength*.24*sin(TIME*2.1+art_uv.x*13.0+art_uv.y*7.0);
  vec2 direction=normalize(vec2(wind_direction.x,wind_direction.y*.35)+vec2(.0001,0.0));
  direction=vec2(direction.x*cos(sprite_rotation)+direction.y*sin(sprite_rotation),-direction.x*sin(sprite_rotation)+direction.y*cos(sprite_rotation));
  local+=movement*sway*wind_response*strength*(.55+.45*strength)*weight*direction;
 }
 // Sampling inside a fixed inset can stretch the first colored pixels into
 // rectangular fringes at the treetop. Outside the sprite stays transparent.
 float inside=step(0.0,local.x)*step(local.x,1.0)*step(0.0,local.y)*step(local.y,1.0);
 vec2 uv=region.xy+clamp(local,vec2(0.0),vec2(1.0))*region.zw;
 vec4 pixel=texture(sprite,uv,crop_style?texture_softness:0.0);
 if(environment_motion==2){
  vec4 original=texture(sprite,region.xy+clamp(art_uv,vec2(0.0),vec2(1.0))*region.zw);
  pixel.rgb=mix(original.rgb,pixel.rgb,water);
  pixel.a=original.a;
 }
 vec3 pigment=mix(pixel.rgb,vec3(.29,.21,.10),health*.75);
 if(crop_style){
  pigment=paint_pigment(pigment,style_saturation,style_contrast)*individual_pigment;
  pigment*=1.0+(paint_hash(floor(world_uv*map_size*85.0))-.5)*paper_grain;
 }
 // Painted sprites already include their own leaf shading. Use neutral day
 // illumination instead of shading a second, fictitious curved 3D surface.
 vec3 night_color=garden_color(pigment,world_uv,vec3(0,1,0),0.0,moonlight,cloud)-pigment*garden_lamp_glow(world_uv,0.0);
 float shade=garden_shadow(world_uv)*(1.0-cloud*.85)*.35;
 vec3 day_color=pigment*day_exposure*(1.0-cloud*.12)*(1.0-shade);
 vec3 color=mix(night_color,day_color,daylight)+pigment*garden_lamp_glow(world_uv,daylight);
 float alpha=pixel.a*inside;
 if(root_detail>0.0){
  vec2 root=(art_uv-vec2(.5,root_anchor))*sprite_world_size;
  if(abs(root.x)<.14 && root.y>-.10 && root.y<.065){
   vec2 soil_delta=(world_uv-soil_center)*map_size;
   float c=cos(soil_rotation);
   float s=sin(soil_rotation);
   soil_delta=vec2(soil_delta.x*c+soil_delta.y*s,-soil_delta.x*s+soil_delta.y*c);
   vec2 soil_uv=clamp(soil_delta/soil_world_size+vec2(.5),vec2(0.0),vec2(1.0));
   vec4 earth=texture(ground_soil,ground_soil_region.xy+soil_uv*ground_soil_region.zw);
   vec3 earth_color=garden_color(paint_pigment(earth.rgb,.92,.94),world_uv,vec3(0,1,0),daylight,moonlight,cloud);
   float bury=smoothstep(-.012,.04,root.y)*(1.0-smoothstep(.045,.09,abs(root.x)))*root_detail;
   color=mix(color,earth_color,bury*.75*earth.a);
   // Two short, imperfect grass blades overlap the foot, not the whole stem.
   float tip=smoothstep(-.085,-.055,root.y)*(1.0-smoothstep(.0,.025,root.y));
   float blade1=1.0-smoothstep(.005,.014,abs(root.x+.052+root.y*.30));
   float blade2=1.0-smoothstep(.005,.013,abs(root.x-.045-root.y*.42));
   float blades=max(blade1,blade2)*tip*root_detail*earth.a;
   vec3 grass_day=garden_color(texture(ground_day,world_uv).rgb,world_uv,vec3(0,1,0),1.0,moonlight,cloud);
   vec3 grass_night=texture(ground_night,world_uv).rgb*(.72+moonlight*.9)*(1.0-cloud*.22);
   vec3 grass_color=mix(grass_night,grass_day,daylight);
   float layered_alpha=blades+alpha*(1.0-blades);
   color=(grass_color*blades+color*alpha*(1.0-blades))/max(layered_alpha,.0001);
   alpha=layered_alpha;
  }
 }
 color=mix(color,mix(vec3(.11,.16,.23),vec3(.66,.73,.69),daylight),smoothstep(.2,.85,fog_amount)*.39);
 if(environment_motion==2 && water>.001 && rain>.01 && SCREEN_UV.y>=.333333){
  vec2 aspect=vec2(max(sprite_world_size.x,.1)/max(sprite_world_size.y,.1),1.0);
  vec2 grid=art_uv*aspect*18.0;
  float ripple=0.0;
  vec2 cell=floor(grid);
  float seed=paint_hash(cell+vec2(phase));
  float clock=TIME*.7+seed*13.0;
  float cycle=floor(clock);
  float age=fract(clock);
  vec2 center=cell+vec2(.25)+vec2(paint_hash(cell+vec2(cycle)),paint_hash(cell+vec2(cycle+29.0)))*.5;
  vec2 center_uv=center/(aspect*18.0);
  float allowed=has_water_mask?texture(water_mask,center_uv).r:texture(sprite,region.xy+center_uv*region.zw).a;
  float ring=1.0-smoothstep(.012,.027,abs(length(grid-center)-age*.23));
  ripple=ring*(1.0-age)*smoothstep(0.0,.08,age)*allowed*step(seed,rain);
  color+=vec3(.28,.39,.40)*ripple*water*rain;
 }
 if(light_source){
  float flicker=environment_motion==3?(.97+.03*sin(TIME*2.1+phase)):1.0;
  color=mix(color,pigment*vec3(1.15,.90,.55)*flicker,1.0-daylight);
 }
 if(has_fixture_night){
  vec4 lit=texture(night_sprite,uv);
  float state=fixture_enabled?(fixture_night_only?1.0-daylight:1.0):0.0;
  vec3 reference=texture(sprite,uv).rgb;
  float warm=smoothstep(.08,.35,lit.r-lit.b)*smoothstep(.06,.28,lit.r-lit.g);
  float difference=max(0.0,lit.r-reference.r)+max(0.0,lit.g-reference.g)*.5;
  float emission=has_emission_mask?texture(emission_mask,uv).r:warm*smoothstep(.04,.3,difference);
  vec3 surface=garden_color(lit.rgb,world_uv,vec3(0,1,0),daylight,moonlight,cloud);
  surface=max(surface,lit.rgb*vec3(.72,.83,1.0)*fixture_night_brightness*(1.0-daylight));
  vec3 illuminated=mix(surface,lit.rgb,emission);
  color=mix(color,illuminated,state);
  alpha=mix(alpha,lit.a*inside,state);
 }
 ALBEDO=color;
 if(soft_atmosphere){
  // Mist and clouds need the faint alpha fringe that solid cutouts discard.
  float border=min(min(local.x,1.0-local.x),min(local.y,1.0-local.y));
  alpha*=smoothstep(0.0,.065,border);
  if(alpha<.001)discard;
 }else if(alpha<.30)discard;
 ALPHA=alpha*opacity;
}
