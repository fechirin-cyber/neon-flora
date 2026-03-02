shader_type canvas_item;
// リールドラム曲面効果 — 円筒パースペクティブ + 照明 (§9.5 拡張)
// blend_mix: 黒オーバーレイのalpha制御で端の暗化を実現

uniform float shadow_strength : hint_range(0.0, 1.0) = 0.45;
uniform float highlight_boost : hint_range(0.0, 0.5) = 0.12;

void fragment() {
	// 1. 中央からの距離 (0=中央, 1=端)
	float dist_from_center = abs(UV.y - 0.5) * 2.0;

	// 2. ドラム曲面の暗化 (cosine曲線で自然な光の落ち方)
	float drum_shadow = 1.0 - cos(dist_from_center * 1.2);
	drum_shadow *= shadow_strength;

	// 3. 左右エッジの軽い暗化 (ドラム側面の曲率)
	float lr_dist = abs(UV.x - 0.5) * 2.0;
	float lr_shadow = pow(lr_dist, 3.0) * 0.15;

	// 4. 総合暗化量 (0=変化なし, 1=完全暗化)
	float total_shadow = clamp(drum_shadow + lr_shadow, 0.0, 1.0);

	// 5. 中央にハイライト (バックライトの焦点) — 白を微量加算
	float center_boost = highlight_boost * (1.0 - dist_from_center * dist_from_center);
	center_boost = max(center_boost - total_shadow, 0.0);

	// 黒オーバーレイ (alpha=total_shadow) + 微量の白 (center_boost)
	COLOR = vec4(center_boost, center_boost, center_boost, total_shadow);
}
