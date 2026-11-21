shader_type canvas_item;
uniform float cool_mix = 0.22;
uniform vec3 tone = vec3(1.0);
void fragment() {
	vec3 rgb = COLOR.rgb;
	float luminance = dot(rgb,vec3(.2126,.7152,.0722));
	float warmth = smoothstep(.08,.3,rgb.r-rgb.b);
	vec3 graded = mix(vec3(luminance),rgb,.83)*vec3(.84,.96,1.05);
	COLOR.rgb = mix(rgb,graded,cool_mix*(1.0-warmth*.7))*tone;
}
