shader_type spatial;
render_mode cull_disabled;
void fragment() {
 vec2 p=UV;
 float r=length(p);
 float vein=pow(max(0.0,cos(atan(p.y,p.x)*12.0)),38.0)*(1.0-smoothstep(.1,1.0,r));
 float fine=sin(r*62.0+sin(atan(p.y,p.x)*7.0))*.013;
 ALBEDO=mix(vec3(.16,.28,.10),vec3(.30,.43,.17),.45+.25*sin(p.x*5.0+p.y*4.0));
 ALBEDO+=vec3(.08,.085,.025)*vein+vec3(fine);
 ROUGHNESS=.78;
}
