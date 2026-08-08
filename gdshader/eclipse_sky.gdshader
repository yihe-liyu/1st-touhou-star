shader_type sky;
// 伪日食天空（官方文档：sky shader 入口是 void sky()，输出 out vec3 COLOR）
// 内置：EYEDIR（像素方向）/ LIGHT0_*（本 fork 阉割风险大——改用 uniform sun_dir 常量）
// 黑圆（noise 扰动边缘）+ 边缘漏光

uniform vec4 sun_tint : source_color = vec4(1.0, 0.86, 0.62, 1.0);  // 暖金（伪日食夕阳感）
uniform float sun_energy : hint_range(0.0, 4.0) = 1.6;   // 太阳不爆亮（否则雾 mix 后剩 10% 仍亮）
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
	// ② 雾：不规则轮廓（半径随方向角扰动 ±30%——不是圆）+ 浓淡斑驳 + 丝缕
	//    太阳内基本全浓罩死太阳光（不切形状只降亮度），雾边淡出
	float n_low = noise(rd.xy * 18.0);              // 大块浓淡
	float n_mid = noise(rd.xy * 45.0 + 7.0);        // 丝缕细节
	float theta = atan(rd.y, rd.x);                 // 方向角（雾边不规则）
	float wob = 0.7 + noise(vec2(theta * 3.0 + 0.5, 0.31)) * 0.6;   // 雾半径 0.7~1.3 摆动
	float fog_radius = sun_size * 1.35 * wob;
	float fog_in = 1.0 - smoothstep(0.0, 1.0, ang / fog_radius);
	float fog_density = fog_in * (0.85 + n_low * 0.3) * (0.8 + n_mid * 0.2);
	col = mix(col, vec3(0.012, 0.011, 0.009), fog_density);
	// ③ 雾边渗光（从雾边向外 0.6× 太阳径——不规则金色光晕）
	if (ang > fog_radius && ang < fog_radius + sun_size * 0.6) {
		float t = (ang - fog_radius) / (sun_size * 0.6);
		col += sun_tint.rgb * pow(1.0 - t, 3.0) * sun_energy * glow * 0.35 * (0.4 + n_mid * 0.9);
	}
	COLOR = col;  // out vec3（官方文档）
}
