shader_type canvas_item;
uniform float strength = 0.60;
void fragment() {
	vec2 q = (UV - vec2(0.51, 0.45)) * vec2(1.15, 1.0);
	float edge = smoothstep(0.22, 0.70, length(q));
	COLOR = vec4(0.008, 0.014, 0.023, edge * strength);
}
