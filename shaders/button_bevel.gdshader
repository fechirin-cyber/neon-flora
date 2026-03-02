shader_type canvas_item;
// ボタン3Dベベル (§8.4)
uniform float bevel_depth : hint_range(0.0, 10.0) = 3.0;
uniform float light_angle : hint_range(0.0, 6.28) = 0.785;
uniform vec4 base_color : source_color = vec4(0.0, 0.83, 1.0, 1.0);
uniform float pressed : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 uv = UV;
	float edge_top = smoothstep(0.0, 0.08, uv.y);
	float edge_bottom = smoothstep(0.0, 0.08, 1.0 - uv.y);
	float edge_left = smoothstep(0.0, 0.06, uv.x);
	float edge_right = smoothstep(0.0, 0.06, 1.0 - uv.x);

	// ベベルハイライト/シャドウ
	float highlight = (1.0 - uv.y) * 0.15 * (1.0 - pressed);
	float shadow = uv.y * 0.1;

	vec3 col = base_color.rgb;
	col += highlight;
	col -= shadow;
	col *= edge_top * edge_bottom * edge_left * edge_right;

	// 押下時暗く
	col = mix(col, col * 0.7, pressed);

	COLOR = vec4(col, base_color.a);
}
