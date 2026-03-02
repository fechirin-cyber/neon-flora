shader_type canvas_item;
// クロームフレーム金属光沢 (§14.5)
uniform float reflection_strength : hint_range(0.0, 1.0) = 0.4;
uniform float roughness : hint_range(0.0, 1.0) = 0.3;
uniform vec4 frame_color : source_color = vec4(0.6, 0.6, 0.65, 1.0);

void fragment() {
	vec2 uv = UV;
	// 垂直グラデーションで金属反射を模倣
	float grad = smoothstep(0.0, 0.5, uv.y) * smoothstep(1.0, 0.5, uv.y);
	float specular = pow(grad, 2.0 / max(roughness, 0.01)) * reflection_strength;
	vec3 col = frame_color.rgb + vec3(specular);
	COLOR = vec4(col, frame_color.a);
}
