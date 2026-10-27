shader_type spatial;
render_mode unshaded,cull_disabled,fog_disabled;
uniform sampler2D soil_normal : source_color,repeat_disable,filter_linear_mipmap;
uniform sampler2D soil_selected : source_color,repeat_disable,filter_linear_mipmap;
uniform vec4 normal_region=vec4(0,0,1,1);
uniform vec4 selected_region=vec4(0,0,1,1);
uniform bool selected=false;
uniform float opacity=1.0;
uniform bool auto_selection=false;
uniform float selection_brightness=.12;
uniform bool custom_surface=false;
uniform float daylight=1.0;
uniform float moonlight=0.0;
uniform float cloud=0.0;
uniform float fog_amount=0.0;
uniform float wetness=0.0;
uniform sampler2D ground_day : source_color,filter_linear_mipmap,repeat_disable;
uniform sampler2D ground_night : source_color,filter_linear_mipmap,repeat_disable;
uniform float edge_grass=.64;
uniform float root_shadow_strength=.17;
uniform float soil_saturation=.92;
uniform float soil_contrast=.94;
uniform float paper_grain=.012;
uniform float plot_phase=0.0;
uniform vec4 root_contacts[36];
uniform int root_count=0;
#include "res://assets/shaders/garden_lighting.gdshaderinc"
#include "res://assets/shaders/garden_painterly.gdshaderinc"
varying vec2 world_uv;
void vertex(){world_uv=(MODEL_MATRIX*vec4(VERTEX,1.0)).xz/map_size+vec2(.5);}
void fragment(){
 vec4 pixel=selected?texture(soil_selected,selected_region.xy+UV*selected_region.zw):texture(soil_normal,normal_region.xy+UV*normal_region.zw);
 if(pixel.a<.35)discard;
 if(selected && auto_selection)pixel.rgb=clamp(pixel.rgb*(1.0+selection_brightness),vec3(0.0),vec3(1.0));
 float grain=paint_hash(floor(world_uv*map_size*85.0))-.5;
 vec3 pigment=paint_pigment(pixel.rgb,soil_saturation,soil_contrast)*(1.0+grain*paper_grain);
 vec3 color=garden_color(pigment*(1.0-wetness*.13),world_uv,vec3(0,1,0),daylight,moonlight,cloud);
 // Preserve the authored soil edge. Sampling the original illustration here
 // mixes unrelated background pixels into moved fields on custom maps.
 float contact=0.0;
 for(int i=0;i<36;i++){
  if(i>=root_count)break;
  vec2 p=(world_uv-root_contacts[i].xy)*map_size/root_contacts[i].zw;
  if(abs(p.x)<2.0 && abs(p.y)<2.0)contact=max(contact,exp(-dot(p,p)*2.4));
 }
 color*=1.0-contact*root_shadow_strength;

 float fog=smoothstep(.2,.85,fog_amount);
 color=mix(color,mix(vec3(.11,.16,.23),vec3(.66,.73,.69),daylight),fog*.39);
 ALBEDO=color;
 ALPHA=pixel.a*opacity;
}
