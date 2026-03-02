shader_type canvas_item;
// 入賞図柄グロー (§14.5)
uniform vec4 glow_color : source_color = vec4(0.0, 1.0, 0.53, 1.0);
uniform float pulse_speed : hint_range(0.0, 10.0) = 3.0;
uniform float glow_strength : hint_range(0.0, 1.0) = 0.4;
uniform float active : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	float pulse = (sin(TIME * pulse_speed) * 0.5 + 0.5) * glow_strength * active;
	vec3 glow = glow_color.rgb * pulse;
	COLOR = vec4(base.rgb + glow * base.a, base.a);
}
