shader_type canvas_item;
render_mode unshaded,blend_add;
uniform float daylight=1.0;
uniform vec4 map_uv_rect=vec4(0.0,0.0,1.0,1.0);
uniform sampler2D scene_color : hint_screen_texture,filter_linear;
#include "res://assets/shaders/garden_lighting.gdshaderinc"
#include "res://assets/shaders/painted_lighting.gdshaderinc"
void fragment(){
 vec3 surface=texture(scene_color,SCREEN_UV).rgb;
 vec2 map_uv=map_uv_rect.xy+UV*map_uv_rect.zw;
 if(any(lessThan(map_uv,vec2(0.0))) || any(greaterThan(map_uv,vec2(1.0))))discard;
 vec3 light=painted_lamp_glow(map_uv,daylight);
 COLOR=vec4((surface*1.8+vec3(.012))*light,1.0);
}
