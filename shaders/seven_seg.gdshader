shader_type canvas_item;
// 7セグLEDグロー (§8.5)
uniform float glow_radius : hint_range(0.0, 10.0) = 2.0;
uniform float glow_intensity : hint_range(0.0, 1.0) = 0.6;
uniform vec4 led_color : source_color = vec4(0.0, 1.0, 0.53, 1.0);

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	// 点灯ピクセルにグロー追加
	float luminance = dot(base.rgb, vec3(0.299, 0.587, 0.114));
	vec3 glow = led_color.rgb * luminance * glow_intensity;
	COLOR = vec4(base.rgb + glow, base.a);
}
