shader_type canvas_item;

// miss 特效 —— 逐渐增大的反色圆
// 边缘有柔化，让反色看起来自然

uniform float circle_radius = 0.0;   // 0→1，圆半径占控件半宽的比值
uniform float alpha = 1.0;           // 整体透明度
uniform float edge_soft: hint_range(0.0, 1.0) = 0.05;

void fragment() {
	vec2 center = vec2(0.5);
	float dist = distance(UV, center);
	
	// 在圆内应用反色
	float mask = 1.0 - smoothstep(circle_radius - edge_soft, circle_radius + edge_soft, dist);
	
	vec4 bg = texture(SCREEN_TEXTURE, SCREEN_UV);
	vec4 inverted = vec4(1.0 - bg.rgb, 1.0);
	
	COLOR = mix(bg, inverted, mask * alpha);
}
