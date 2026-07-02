shader_type canvas_item;

/// 中间黑色矩形半宽（归一化 0~1），0.3 = 中间 60% 宽的区域是黑色
uniform float bar_width : hint_range(0.0, 0.5) = 0.3;
/// 边缘渐隐宽度（归一化 0~1）
uniform float fade_width : hint_range(0.0, 0.5) = 0.15;
/// 中间黑色的不透明度（0.0=全透, 1.0=全黑）
uniform float opacity : hint_range(0.0, 1.0) = 0.65;

void fragment() {
	float dist_from_center = abs(UV.x - 0.5);
	float edge_start = bar_width;
	float edge_end = bar_width + fade_width;
	float alpha = (1.0 - smoothstep(edge_start, edge_end, dist_from_center)) * opacity;
	COLOR = vec4(0.0, 0.0, 0.0, alpha);
}
