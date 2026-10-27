// Stable world-space detail, shared by soil and plants. No new noise texture.
float paint_hash(vec2 p){
 vec3 q=fract(vec3(p.xyx)*.1031);
 q+=dot(q,q.yzx+33.33);
 return fract((q.x+q.y)*q.z);
}
vec3 paint_pigment(vec3 color,float saturation,float contrast){
 float luminance=dot(color,vec3(.2126,.7152,.0722));
 color=mix(vec3(luminance),color,saturation);
 return max(vec3(0.0),mix(vec3(.18),color,contrast));
}
