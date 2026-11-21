shader_type canvas_item;
uniform float blend_width : hint_range(0.001, 0.1) = 0.03;
void fragment() {
 COLOR.a *= smoothstep(0.0, blend_width, UV.x);
}
