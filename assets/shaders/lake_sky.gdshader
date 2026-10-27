shader_type sky;
uniform float daylight=1.;
uniform vec3 moon_direction=vec3(0.,.5,-.8);
uniform float phase=.5;
uniform float clouds=0.;
float hash(vec3 p){return fract(sin(dot(p,vec3(127.1,311.7,74.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);return mix(mix(hash(vec3(i,0)),hash(vec3(i+vec2(1,0),0)),f.x),mix(hash(vec3(i+vec2(0,1),0)),hash(vec3(i+vec2(1,1),0)),f.x),f.y);}
void sky(){
 vec3 dir=normalize(EYEDIR);
 float h=smoothstep(-.08,.65,dir.y);
 vec3 night=mix(vec3(.008,.015,.032),vec3(.002,.004,.012),h);
 vec3 day=mix(vec3(.64,.72,.73),vec3(.22,.40,.55),h);
 vec3 color=mix(night,day,daylight);
 vec3 cell=floor(dir*400.);
 float star=step(.997,hash(cell))*pow(max(0.,1.-length(fract(dir*400.)-.5)*2.),2.);
 color+=star*(1.-daylight)*(1.-clouds)*smoothstep(.02,.25,dir.y)*1.8;
 float facing=clamp(dot(dir,normalize(moon_direction)),-1.,1.);
 float radius=.006;
 float distance=acos(facing);
 vec3 right=normalize(cross(vec3(0,1,0),normalize(moon_direction)));
 vec3 up=normalize(cross(normalize(moon_direction),right));
 vec2 uv=vec2(dot(dir,right),dot(dir,up))/radius;
 float disk=1.-smoothstep(.92,1.,length(uv));
 vec3 normal=vec3(uv,sqrt(max(0.,1.-dot(uv,uv))));
 float lit=smoothstep(-.02,.08,dot(normal,vec3(sin(phase*6.2831853),0.,-cos(phase*6.2831853))));
 float crater=.83+.17*noise(uv*13.);
 float halo=exp(-distance*distance/0.003)*.018;
 float visible=(1.-daylight)*smoothstep(-.015,.04,moon_direction.y);
 if (!AT_CUBEMAP_PASS) { color+=vec3(.88,.92,1.)*disk*lit*crater*visible; }
 color+=vec3(.24,.36,.58)*halo*visible;
 vec2 p=dir.xz/max(.12,dir.y+.18)*2.+vec2(TIME*.001,0.);
 float cloud=noise(p)*.66+noise(p*2.4)*.34;
 color=mix(color,mix(vec3(.045,.058,.085),vec3(.78,.8,.78),daylight),smoothstep(.58-clouds*.25,.83,cloud)*(.12+clouds*.75));
 COLOR=color;
}
