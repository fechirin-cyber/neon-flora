shader_type canvas_item;
// リール回転中モーションブラー — 実機パチスロのリール残像を再現 (§9.1)
// blur_strength : 0.0 (停止) 〜 1.0 (フル回転 80RPM)
// blur_amount   : 最大ブラーピクセル数 (デフォルト 12px)
// 縦方向のみ 5-tap ガウシアンブラー（リールは縦スクロールのため）
// mobile renderer で 60fps 維持を前提とした軽量実装

uniform float blur_strength : hint_range(0.0, 1.0) = 0.0;
uniform float blur_amount   : hint_range(0.0, 20.0) = 12.0;

void fragment() {
	if (blur_strength < 0.01) {
		// ブラーなし — そのまま描画（停止時・加速極初期）
		COLOR = texture(TEXTURE, UV);
	} else {
		// 縦方向 5-tap ガウシアンブラー
		// ウェイトは正規分布近似（合計 = 1.0 になるよう正規化不要な値）
		float pixel_size = TEXTURE_PIXEL_SIZE.y;
		float offset = blur_amount * blur_strength * pixel_size;

		// ガウシアンウェイト (5-tap: center + 4 samples)
		// weights[0]: center, weights[1..4]: ±1〜4 tap
		const float w0 = 0.227027;
		const float w1 = 0.194595;
		const float w2 = 0.121622;
		const float w3 = 0.054054;
		const float w4 = 0.016216;
		// 合計 = w0 + 2*(w1+w2+w3+w4) = 0.227027 + 2*0.386487 = 1.000001 ≒ 1.0

		vec4 col = texture(TEXTURE, UV) * w0;

		float o1 = offset * 1.0 / 4.0;
		float o2 = offset * 2.0 / 4.0;
		float o3 = offset * 3.0 / 4.0;
		float o4 = offset * 4.0 / 4.0;

		col += texture(TEXTURE, UV + vec2(0.0,  o1)) * w1;
		col += texture(TEXTURE, UV - vec2(0.0,  o1)) * w1;
		col += texture(TEXTURE, UV + vec2(0.0,  o2)) * w2;
		col += texture(TEXTURE, UV - vec2(0.0,  o2)) * w2;
		col += texture(TEXTURE, UV + vec2(0.0,  o3)) * w3;
		col += texture(TEXTURE, UV - vec2(0.0,  o3)) * w3;
		col += texture(TEXTURE, UV + vec2(0.0,  o4)) * w4;
		col += texture(TEXTURE, UV - vec2(0.0,  o4)) * w4;

		COLOR = col;

		// 回転中は若干コントラストを下げる（実機の残像感を強調）
		float luma = dot(COLOR.rgb, vec3(0.299, 0.587, 0.114));
		COLOR.rgb = mix(COLOR.rgb, vec3(luma), blur_strength * 0.12);
	}
}
