shader_type canvas_item;

uniform float progress : hint_range(0, 1) = 0.0;
uniform float alpha_mult : hint_range(0, 1) = 1.0;

// 伪随机哈希
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

void fragment() {
	const float GRID = 75.0;  // 75×75 粒子网格

	// 每个像素所属的粒子
	vec2 grid_uv = floor(UV * GRID) / GRID;

	// 每个粒子的随机属性
	float seed = hash(grid_uv);
	float angle = seed * 6.2832;          // 随机飞行方向
	float radius = hash(grid_uv + 0.5) * 0.65 + 0.12;  // 初始分散范围更大
	float delay = hash(grid_uv + 1.0);    // 随机延迟 0~1

	// 带延迟的局部进度（粒子们不同时出发，但同时到达）
	float local_progress = smoothstep(delay * 0.3, 1.0, progress);

	// 从随机方向飞向正确位置
	vec2 dir = vec2(cos(angle), sin(angle));
	float scatter = radius * (1.0 - pow(local_progress, 1.5));
	vec2 sample_uv = UV + dir * scatter;
	// 超出边界的粒子直接透明，不要 clamp 到矩形
	if (sample_uv.x < 0.0 || sample_uv.x > 1.0 || sample_uv.y < 0.0 || sample_uv.y > 1.0) {
		COLOR = vec4(0.0);
		return;
	}
	vec4 tex = texture(TEXTURE, sample_uv);

	// 飞行途中的辉光拖尾
	float flight = sin(local_progress * 3.14159) * 2.0;
	flight = max(0.0, flight - 0.6) * 2.5;
	float flight_glow = flight * 0.25;

	// 到达正确位置时的闪光
	float arrive_glow = exp(-pow((local_progress - 1.0) * 15.0, 2.0)) * 0.6;

	float glow = flight_glow + arrive_glow;
	vec3 glow_color = vec3(0.5, 0.7, 1.0) * glow;

	// 粒子逐渐变亮
	float brightness = 0.25 + 0.75 * local_progress;

	COLOR = vec4(tex.rgb * brightness + glow_color, tex.a * local_progress * alpha_mult);
}
