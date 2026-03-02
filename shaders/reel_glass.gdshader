shader_type canvas_item;
// リール窓ガラス反射 — 上部にうっすら白い反射帯 (§9.5)
// 実機のリール窓ガラスに蛍光灯が映り込む効果を再現
// Note: ColorRectのTEXTUREは不透明白を返すため使用禁止。alpha制御で反射を実現。

uniform float reflection_opacity : hint_range(0.0, 0.3) = 0.06;
uniform float reflection_y_start : hint_range(0.0, 0.3) = 0.02;
uniform float reflection_y_end : hint_range(0.0, 0.5) = 0.18;

void fragment() {
	// 上部に微かな反射帯 (smoothstep で山型)
	float mid = (reflection_y_start + reflection_y_end) * 0.5;
	float refl = smoothstep(reflection_y_start, mid, UV.y)
	           * smoothstep(reflection_y_end, mid, UV.y);
	// 白い反射をalpha制御で描画（反射部分のみ微量の白、それ以外は完全透明）
	COLOR = vec4(1.0, 1.0, 1.0, refl * reflection_opacity);
}
