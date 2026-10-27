shader_type canvas_item;
uniform sampler2D mask_image : filter_linear,repeat_disable;
void fragment(){
 vec4 pixel=texture(TEXTURE,UV);
 float selected=texture(mask_image,UV).r;
 COLOR=vec4(mix(pixel.rgb,vec3(.05,.65,1.0),selected*.48),max(pixel.a,selected*.48));
}
