shader_type canvas_item;
// リールバックライト — Y位置グラデーション付き暖白色光 (§9.4 強化)
// 中央が最も明るく、上下に向かって減衰（バックライトの照射分布を再現）
uniform float backlight_intensity : hint_range(0.0, 1.0) = 0.25;
uniform vec4 backlight_color : source_color = vec4(1.0, 0.98, 0.93, 1.0);

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	// 中央が最も明るく、上下に向かって減衰
	float center_factor = 1.0 - abs(UV.y - 0.5) * 1.2;
	center_factor = clamp(center_factor, 0.3, 1.0);
	COLOR = base + backlight_color * backlight_intensity * center_factor * base.a;
	COLOR.a = base.a;
}
