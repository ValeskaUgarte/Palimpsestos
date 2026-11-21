shader_type canvas_item;
uniform float coverage : hint_range(0.0,1.0) = 0.0;
void fragment() {
 vec2 p = (UV-vec2(0.48,0.53))*vec2(1.78,1.0);
 float angle = atan(p.y,p.x);
 float edge = length(p)+sin(angle*7.0+length(p)*11.0)*0.035+sin(angle*13.0)*0.012;
 float alpha = smoothstep(edge-0.045,edge+0.045,coverage*1.35-0.06);
 COLOR=vec4(vec3(0.018,0.025,0.025),alpha);
}
