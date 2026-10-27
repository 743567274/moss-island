shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_never,fog_disabled;
uniform float rain=0.0;
uniform float effect_depth=.65;
uniform bool debug_centers=false;
uniform vec2 map_size=vec2(32.0,18.0);
uniform vec2 water_points[8];
uniform float water_widths[8];
uniform int water_count=7;
uniform bool has_map_water=false;
uniform sampler2D map_water_mask : filter_linear,repeat_disable;
uniform vec2 region_points[64];
uniform int region_count=0;
varying float age;
varying vec2 map_uv;
float random_value(float x){return fract(sin(x*127.1+311.7)*43758.5453);}
void vertex(){
 float seed=INSTANCE_CUSTOM.x;
 float clock=TIME*(.65+seed*.4)+seed*11.0;
 age=fract(clock);
 float cycle=floor(clock);
 float key=seed*913.0+cycle*17.0;
 vec2 uv=vec2(mix(.04,.96,random_value(key)),mix(.38,.94,random_value(key+2.0)));
 if(has_map_water && region_count>0){
  int sample_index=min(region_count-1,int(floor(random_value(key+3.0)*float(region_count))));
  uv=region_points[sample_index]+vec2(random_value(key+4.0)-.5,random_value(key+5.0)-.5)*.008;
 }
 if(INSTANCE_CUSTOM.y>.5 && !has_map_water && water_count>=2){
  int index=3+int(floor(random_value(key)*float(max(1,water_count-4))));
  index=min(index,water_count-2);
  float t=random_value(key+4.0);
  uv=mix(water_points[index],water_points[index+1],t);
  uv.x+=(random_value(key+7.0)-.5)*mix(water_widths[index],water_widths[index+1],t)*1.2;
 }
 vec3 position=vec3((uv.x-.5)*map_size.x+VERTEX.x,effect_depth,(uv.y-.5)*map_size.y+VERTEX.z);
 map_uv=position.xz/map_size+vec2(.5);
 POSITION=PROJECTION_MATRIX*VIEW_MATRIX*vec4(position,1.0);
}
void fragment(){
 if(SCREEN_UV.y<.333333 || rain<.02)discard;
 if(has_map_water && texture(map_water_mask,map_uv).r<.3)discard;
 float r=length(UV-.5);
 float ring=(1.0-smoothstep(.012,.034,abs(r-age*.48)))*(1.0-age)*smoothstep(0.0,.08,age);
 if(debug_centers)ring=1.0-smoothstep(.03,.045,r);
 ALBEDO=vec3(.73,.85,.84);
 ALPHA=ring*rain*.5;
}
