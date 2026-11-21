shader_type canvas_item;
// Funde el borde DERECHO de una imagen de fondo con la que está detrás (para que la unión no se note).
uniform float fade_width : hint_range(0.001, 0.4) = 0.12;
void fragment() {
	COLOR.a *= 1.0 - smoothstep(1.0 - fade_width, 1.0, UV.x);
}
