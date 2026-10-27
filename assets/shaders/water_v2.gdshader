shader_type spatial;
render_mode cull_disabled;
uniform float rain=0.0;
uniform float cloud=0.0;
uniform float ice=0.0;
uniform float daylight=1.0;
uniform float wind=.2;
varying vec3 wp;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
void vertex(){wp=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 vec2 p=wp.xz;
 float wave=sin(p.x*2.4+p.y*1.5+TIME*.45)+sin(p.y*4.5-p.x*.7-TIME*.6)*.35;
 vec2 grid=p*.8;
 float seed=hash(floor(grid));
 float age=fract(TIME*(.7+seed*.4)+seed*9.0);
 vec2 center=vec2(.22+seed*.55,.25+hash(floor(grid)+5.0)*.5);
 float distance=length(fract(grid)-center);
 float ring=(1.0-smoothstep(.010,.026,abs(distance-age*.47)))*(1.0-age);
 float second=(1.0-smoothstep(.010,.022,abs(distance-age*.47+.06)))*(1.0-age)*.45;
 ALBEDO=mix(vec3(.19,.42,.42),vec3(.12,.28,.34),1.0-daylight)+wave*.012;
 ALBEDO=mix(ALBEDO,vec3(.28,.36,.38)*(.45+daylight*.55),cloud*.55);
 ALBEDO+=vec3(.19,.24,.22)*(ring+second)*rain*(1.0-ice)*(1.0-smoothstep(12.0,22.0,length(p)));
 ALBEDO=mix(ALBEDO,vec3(.59,.74,.77),ice);
 NORMAL=normalize(NORMAL+vec3(sin(p.x*2.4+TIME*.5)*.025,0.0,cos(p.y*2.1-TIME*.4)*.025)*(1.0-ice));
 ROUGHNESS=.48;SPECULAR=.3;
}
