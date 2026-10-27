uniform sampler2D light_owner_0 : filter_linear,repeat_disable;
uniform sampler2D light_owner_1 : filter_linear,repeat_disable;
uniform sampler2D light_owner_2 : filter_linear,repeat_disable;
uniform sampler2D light_owner_3 : filter_linear,repeat_disable;
uniform vec4 light_owner_rects[4];
uniform vec4 light_owner_styles[4];
float owner_light_weight(vec2 uv,int i){
 vec4 style=light_owner_styles[i];
 if(style.w<=0.0)return 1.0;
 vec4 rect=light_owner_rects[i];
 vec2 delta=uv*vec2(1920.0,1080.0)-rect.xy;
 float c=cos(style.z); float s=sin(style.z);
 vec2 p=vec2(delta.x*c+delta.y*s,-delta.x*s+delta.y*c)/max(rect.zw,vec2(.001))+style.xy;
 if(any(lessThan(p,vec2(0.0))) || any(greaterThan(p,vec2(1.0))))return 1.0;
 float alpha=0.0;
 if(i==0)alpha=texture(light_owner_0,p).a;
 else if(i==1)alpha=texture(light_owner_1,p).a;
 else if(i==2)alpha=texture(light_owner_2,p).a;
 else alpha=texture(light_owner_3,p).a;
 return 1.0-alpha*style.w;
}
uniform sampler2D light_mask_0 : filter_linear,repeat_disable;
uniform sampler2D light_mask_1 : filter_linear,repeat_disable;
uniform sampler2D light_mask_2 : filter_linear,repeat_disable;
uniform sampler2D light_mask_3 : filter_linear,repeat_disable;
uniform vec4 light_mask_rects[4];
uniform vec4 light_mask_transforms[4];
float painted_light_weight(vec2 uv,int i){
 vec4 transform=light_mask_transforms[i];
 vec2 delta=(uv-transform.xy)*map_size;
 float c=cos(transform.z);
 float s=sin(transform.z);
 uv=vec2(delta.x*c+delta.y*s,-delta.x*s+delta.y*c)/map_size+transform.xy;
 vec4 bounds=light_mask_rects[i];
 vec2 p=(uv-bounds.xy)/max(bounds.zw,vec2(.000001));
 if(any(lessThan(p,vec2(0.0))) || any(greaterThan(p,vec2(1.0))))return 1.0;
 if(i==0)return texture(light_mask_0,p).r;
 if(i==1)return texture(light_mask_1,p).r;
 if(i==2)return texture(light_mask_2,p).r;
 return texture(light_mask_3,p).r;
}
vec3 painted_lamp_glow(vec2 uv,float day){
 vec3 glow=vec3(0.0);
 for(int i=0;i<4;i++)glow+=local_lamp_color[i].rgb*garden_lamp_weight(uv,i,day)*painted_light_weight(uv,i)*owner_light_weight(uv,i);
 return glow;
}
