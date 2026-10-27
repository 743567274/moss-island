shader_type spatial;
render_mode cull_disabled;
uniform sampler2D loam : source_color, filter_linear_mipmap, repeat_enable;
uniform bool selected=false;
uniform vec2 selected_center=vec2(0.0);
varying vec3 world_position;
void vertex() { world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
 vec2 uv=world_position.xz*.85;
 vec3 earth=texture(loam,uv).rgb;
 float grain=sin(world_position.x*83.0+sin(world_position.z*47.0))*sin(world_position.z*91.0);
 ALBEDO=earth*vec3(.66,.57,.46)*(1.0+grain*.045);
 vec2 local=abs((world_position.xz-selected_center)/vec2(.89,.76));
 float r=pow(pow(local.x,4.0)+pow(local.y,4.0),.25);
 float edge=smoothstep(.82,.85,r)*(1.0-smoothstep(.88,.91,r));
 if(selected) { ALBEDO=mix(ALBEDO,vec3(.67,.61,.34),edge*.7); }
 ROUGHNESS=.96;
}
