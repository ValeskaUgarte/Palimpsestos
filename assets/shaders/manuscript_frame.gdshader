shader_type canvas_item;
render_mode unshaded;

// Una sola capa transparente: sin leer la pantalla ni oscurecer el centro.
uniform float edge_strength : hint_range(0.0, 0.5) = 0.22;
uniform vec4 ink_color : source_color = vec4(0.045, 0.032, 0.055, 1.0);

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float edge = smoothstep(0.40, 1.32, length(p * vec2(0.83, 1.0)));
	float top_bottom = smoothstep(0.68, 1.0, abs(p.y));
	float alpha = clamp(edge * edge_strength + top_bottom * 0.055, 0.0, 0.34);
	COLOR = vec4(ink_color.rgb, alpha);
}
