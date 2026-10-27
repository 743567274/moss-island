shader_type canvas_item;
uniform float highlight=0.0;
void fragment(){
 vec4 pixel=texture(TEXTURE,UV)*COLOR;
 pixel.rgb=clamp(pixel.rgb*(1.0+highlight),vec3(0.0),vec3(1.0));
 COLOR=pixel;
}
