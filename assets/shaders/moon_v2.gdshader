shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_never,fog_disabled;
uniform float illumination=1.0;
uniform float cloud=0.0;
void fragment(){
 vec2 p=(UV-.5)*2.0;
 float rim=1.0-smoothstep(.84,.99,length(p));
 float lit=smoothstep(-.12,.12,p.x+illumination*2.0-1.0);
 float crater=.88+.06*sin(p.x*15.0+p.y*9.0)*sin(p.y*13.0-p.x*3.0);
 ALBEDO=vec3(.78,.87,.91)*crater;
 ALPHA=rim*lit*(1.0-cloud*.85);
}
