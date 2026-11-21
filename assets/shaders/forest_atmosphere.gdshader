shader_type canvas_item;
uniform float night_mix : hint_range(0.0, 1.0) = 0.86;
void fragment() {
 vec3 rgb = COLOR.rgb;
 float luma = dot(rgb, vec3(0.2126,0.7152,0.0722));
 vec3 cool = mix(vec3(luma), rgb, 0.7) * vec3(0.20,0.35,0.39);
 // Protege luces cálidas y conserva detalle de caminos y rostros.
 float warm = smoothstep(0.12,0.45,rgb.r-rgb.b) * smoothstep(0.35,0.85,luma);
 COLOR.rgb = mix(rgb, cool, night_mix * (1.0-warm*0.6));
}
