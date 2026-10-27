shader_type canvas_item;
render_mode unshaded;
uniform bool show_erased=false;
#include "res://assets/shaders/garden_lighting.gdshaderinc"
#include "res://assets/shaders/painted_lighting.gdshaderinc"
void fragment(){
 vec4 surface=texture(TEXTURE,UV);
 vec3 light=painted_lamp_glow(UV,0.0);
 vec3 color=surface.rgb+(surface.rgb*1.8+vec3(.012))*light;
 if(show_erased)color=mix(color,vec3(.8,.12,.08),(1.0-painted_light_weight(UV,0))*.45);
 COLOR=vec4(color,surface.a);
}
