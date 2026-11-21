shader_type canvas_item;
// Recorte de gutters en poses extendidas; conserva espada y botas completas.
uniform vec2 clip_right_below = vec2(2.0);
uniform vec2 clip_left_above = vec2(-1.0);
void fragment() {
 vec4 sampled = COLOR;
 if ((UV.x > clip_right_below.x && UV.y > clip_right_below.y) ||
     (UV.x < clip_left_above.x && UV.y < clip_left_above.y)) sampled.a = 0.0;
 COLOR = sampled;
}
