shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled, depth_draw_opaque;
uniform sampler2D landscape : source_color, filter_linear_mipmap;
uniform float daylight=1.0;
uniform float cloud=0.0;
void fragment(){
 vec3 pigment=texture(landscape,UV).rgb;
 vec3 night=pigment*vec3(.12,.22,.37);
 ALBEDO=mix(night,pigment,daylight);
 ALBEDO=mix(ALBEDO,ALBEDO*vec3(.88,.93,.96),cloud*.45);
}
