shader_type canvas_item;
render_mode unshaded;
uniform float amount=0.0;
uniform float opacity=.65;
uniform float speed=1.0;
uniform float daylight=1.0;
uniform sampler2D density_field : filter_linear,repeat_enable;
float fog_noise(vec2 p){
 return texture(density_field,p*.16).r;
}
float fog_layers(vec2 p){
 return fog_noise(p)*.65+fog_noise(p*2.03+vec2(7,19))*.29+fog_noise(p*4.11+vec2(29,3))*.06;
}
void fragment(){
 float time=TIME*.012*speed;
 vec2 screen=SCREEN_UV;
 vec2 p=screen*vec2(5.8,4.2);
 vec2 warp=vec2(fog_noise(p*.65+vec2(-time*.3,5)),fog_noise(p*.8+vec2(8,time*.2)))-.5;
 float density=fog_layers(p+warp*1.3-vec2(time,time*.08));
 float distance=1.0-smoothstep(.16,.82,screen.y);
 float banks=smoothstep(.265,.795,density);
 float clearings=smoothstep(.165,.615,density);
 float ground=smoothstep(.23,.48,screen.y)*(1.0-smoothstep(.88,1.06,screen.y));
 float mist=distance*(.12+.48*banks)+ground*banks*clearings*.65;
 vec3 tint=mix(vec3(.16,.22,.30),vec3(.78,.83,.79),daylight);
 float alpha=clamp((1.0-exp(-mist*2.2))*opacity*smoothstep(.15,.85,amount),0.0,.82);
 COLOR=vec4(tint,alpha);
}
