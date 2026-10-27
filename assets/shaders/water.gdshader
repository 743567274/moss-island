shader_type spatial;
render_mode cull_disabled;
uniform vec3 water_color : source_color = vec3(.14,.26,.24);
uniform float daylight=1.;
uniform float ice_factor=0.;
uniform vec3 moon_direction=vec3(0,.5,-.8);
uniform float moon_energy=0.;
varying vec3 wp;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void vertex(){wp=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;}
void fragment(){
 vec2 p=wp.xz;
 float a=dot(p,vec2(.53,.848))*3.8-TIME*.72;
 float b=dot(p,vec2(.287,.958))*7.3-TIME*1.05+1.7;
 float c=dot(p,vec2(.643,.766))*14.1-TIME*1.37;
 float detail=1.-smoothstep(20.,95.,length(CAMERA_POSITION_WORLD.xz-p));
 vec2 slope=vec2(.53,.848)*cos(a)*.065+vec2(.287,.958)*cos(b)*.034;
 slope+=vec2(.643,.766)*cos(c)*.012*(1.-smoothstep(.4,1.5,fwidth(c)));
 slope*=mix(.12,1.,detail)*(1.-ice_factor);
 vec3 normal=normalize(vec3(-slope.x,1.,-slope.y));
 vec3 view=normalize(CAMERA_POSITION_WORLD-wp);
 float fresnel=pow(1.-max(0.,dot(view,normal)),5.);
 float broken=noise(vec2(p.x*2.2,p.y*.8-TIME*.08));
 float phase=a*2.1+noise(p*.5)*2.;
 float width=max(.20,fwidth(phase)*.7);
 float distance=abs(fract(phase/6.2831853+.5)-.5)*6.2831853;
 float crest=exp(-pow(distance/width,2.))*.2/width*pow(smoothstep(.38,.82,broken),2.)*detail;
 ALBEDO=water_color+vec3(.0015)*sin(p.y*1.7+sin(p.x*.3)-TIME*.2)*detail;
 ALBEDO+=vec3(.04)*crest*(1.-ice_factor);
 ALBEDO=mix(ALBEDO,vec3(.43,.55,.57),ice_factor);
 ROUGHNESS=mix(.26,.65,ice_factor);METALLIC=0.;SPECULAR=.45;
 NORMAL=normalize((VIEW_MATRIX*vec4(normal,0.)).xyz);
 float moon_glint=pow(max(0.,dot(normal,normalize(view+normalize(moon_direction)))),220.);
 vec3 sky=mix(vec3(.006,.014,.03),vec3(.22,.33,.37),daylight);
 EMISSION=sky*(.04+fresnel*.18)+vec3(.55,.68,.88)*moon_glint*moon_energy*.7*(1.-ice_factor);
}

void light(){
 float lum=dot(LIGHT_COLOR,vec3(.2126,.7152,.0722));
 vec3 hue=mix(vec3(lum),LIGHT_COLOR,.3);
 DIFFUSE_LIGHT+=ALBEDO*hue*ATTENUATION*max(dot(NORMAL,LIGHT),0.)*.25;
 float spec=pow(max(0.,dot(NORMAL,normalize(LIGHT+VIEW))),150.);
 SPECULAR_LIGHT+=hue*ATTENUATION*spec*.035;
}
