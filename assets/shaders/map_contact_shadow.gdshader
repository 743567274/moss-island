shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_never,fog_disabled;
uniform float strength=.2;
void fragment(){
 float d=length((UV-.5)*2.0);
 ALBEDO=vec3(.07,.10,.07);
 ALPHA=exp(-d*d*4.0)*(1.0-smoothstep(.7,1.0,d))*strength;
}
