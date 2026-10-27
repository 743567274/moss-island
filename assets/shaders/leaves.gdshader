shader_type spatial;
render_mode cull_disabled;
uniform vec4 leaf_color:source_color=vec4(.32,.46,.24,1.);
uniform float wind_strength=.10;
varying float height;
void vertex(){ height=UV.y; vec3 p=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz; VERTEX.x+=sin(TIME*.8+p.x*.7+p.z*.8)*wind_strength*UV.y; }
void fragment(){ ALBEDO=leaf_color.rgb*mix(.72,1.13,height); ROUGHNESS=.92; }
