shader_type canvas_item;
// 回転中モーションブラー — 実機パチスロのリール残像を再現
// blur_strength: 0.0 (停止) 〜 1.0 (フル回転80RPM)
// 縦方向のみブラー（リールは縦スクロールのため）

uniform float blur_strength : hint_range(0.0, 1.0) = 0.0;
uniform float blur_samples : hint_range(2.0, 8.0) = 4.0;
uniform float blur_spread : hint_range(0.0, 0.08) = 0.04;

void fragment() {
	if (blur_strength < 0.01) {
		COLOR = texture(TEXTURE, UV);
	} else {
		float spread = blur_spread * blur_strength;
		vec4 col = vec4(0.0);
		float total = 0.0;
		int samples = int(blur_samples);
		for (int i = -samples; i <= samples; i++) {
			float offset = float(i) / float(samples) * spread;
			float weight = 1.0 - abs(float(i)) / float(samples + 1);
			col += texture(TEXTURE, UV + vec2(0.0, offset)) * weight;
			total += weight;
		}
		COLOR = col / total;
		// 回転中は若干コントラストを下げる（実機の残像感）
		COLOR.rgb = mix(COLOR.rgb, vec3(dot(COLOR.rgb, vec3(0.299, 0.587, 0.114))), blur_strength * 0.15);
	}
}
