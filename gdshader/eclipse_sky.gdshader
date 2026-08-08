shader_type sky;
// 伪日食天空（官方文档：sky shader 入口是 void sky()，输出 out vec3 COLOR）
// 内置：EYEDIR（像素方向）/ LIGHT0_*（本 fork 阉割风险大——改用 uniform sun_dir 常量）
// 黑圆（noise 扰动边缘）+ 边缘漏光

uniform vec4 sun_tint : source_color = vec4(0.92, 0.95, 1.0, 1.0);
uniform float sun_energy : hint_range(0.0, 4.0) = 3.0;
uniform float sun_size : hint_range(0.01, 0.12) = 0.055;   // 太阳总角半径（弧度，游戏感要大）
uniform float black_ratio : hint_range(0.0, 1.0) = 0.72;   // 黑圆占太阳比例
uniform float glow : hint_range(0.0, 2.5) = 1.0;           // 击破回光：漏光增强
uniform vec3 sun_dir = vec3(-0.26, 0.12, -0.96);           // 左前上方（方位 -15°、仰角 7°）

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void sky() {
	vec3 rd = normalize(EYEDIR);
	// 天色：地平线稍亮、天顶暗（压抑）
	float h = clamp(rd.y, 0.0, 1.0);
	vec3 col = mix(vec3(0.20, 0.21, 0.25), vec3(0.08, 0.09, 0.12), pow(h, 0.55));
	if (rd.y < 0.0) {
		col = mix(vec3(0.05, 0.05, 0.07), vec3(0.20, 0.21, 0.25), clamp(-rd.y, 0.0, 1.0) * 0.6);
	}
	// 太阳（固定方向常量，不依赖 LIGHT0）
	float ang = acos(clamp(dot(rd, normalize(sun_dir)), -1.0, 1.0));
	// ① 太阳本体：规矩的亮圆（中心亮边缘暗，干净圆边）
	if (ang < sun_size) {
		float e = ang / sun_size;
		col += sun_tint.rgb * pow(1.0 - e, 1.5) * sun_energy * glow;
	}
	// ② 黑雾遮罩：不规则边缘 + 透明度不均匀（斑驳，像雾盖住太阳）
	float n_low = noise(rd.xy * 22.0);            // 大块云状（透明度斑驳）
	float n_edge = noise(rd.xy * 55.0 + 13.7);    // 边缘细节（不规则边）
	float r_black = sun_size * black_ratio * (0.92 + n_low * 0.24);
	if (ang < r_black) {
		float shade = clamp(1.0 - (r_black - ang) / (sun_size * 0.28), 0.0, 1.0);  // 中心实 边缘虚
		float alpha = mix(0.30, 1.0, shade);
		alpha *= 0.65 + n_low * 0.5 + n_edge * 0.15;  // 透明度不均匀（黑雾斑驳）
		col = mix(col, vec3(0.008, 0.008, 0.015), clamp(alpha, 0.0, 1.0));
	}
	COLOR = col;  // out vec3（官方文档）
}
