shader_type canvas_item;
render_mode unshaded,blend_add;
uniform float daylight=1.0;
uniform sampler2D receiver : filter_linear,repeat_disable;
uniform sampler2D scene_color : hint_screen_texture,filter_linear;
#include "res://assets/shaders/garden_lighting.gdshaderinc"
#include "res://assets/shaders/painted_lighting.gdshaderinc"
void fragment(){
 vec3 surface=texture(scene_color,SCREEN_UV).rgb;
 vec3 light=painted_lamp_glow(UV,daylight);
 COLOR=vec4((surface*1.8+vec3(.012))*light,1.0);
}
