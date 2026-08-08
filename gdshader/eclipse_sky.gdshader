shader_type sky;
// 伪日食天空（此 fork sky shader 可用内置：EULER 方向 / UV / TIME / COLOR）
// 暗色天色 + 清晰太阳圆斑 + noise 黑圆遮罩（边缘漏光）

uniform vec4 sun_tint : source_color = vec4(0.92, 0.95, 1.0, 1.0);
uniform float sun_energy : hint_range(0.0, 4.0) = 2.2;
uniform float sun_size : hint_range(0.01, 0.06) = 0.022;    // 黑圆角半径（弧度）
uniform float ring_ratio : hint_range(0.0, 1.0) = 0.55;     // 漏光环宽度（相对黑圆）
uniform float glow : hint_range(0.0, 2.5) = 1.0;            // 击破回光：漏光增强
uniform vec3 sun_dir = vec3(-0.35, 0.14, -0.92);            // 左前上方地平线附近（世界方向）

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

void fragment() {
	// EULER（弧度欧拉）→ 世界方向
	vec3 rd = normalize(vec3(
			cos(EULER.x) * sin(EULER.y),
			sin(EULER.x),
			-cos(EULER.x) * cos(EULER.y)));
	// 天色：地平线稍亮、天顶暗（压抑）
	float h = clamp(rd.y, 0.0, 1.0);
	vec3 col = mix(vec3(0.20, 0.21, 0.25), vec3(0.08, 0.09, 0.12), pow(h, 0.55));
	if (rd.y < 0.0) {
		col = mix(vec3(0.05, 0.05, 0.07), vec3(0.20, 0.21, 0.25), clamp(-rd.y, 0.0, 1.0) * 0.6);
	}
	// 太阳（黑圆 + 边缘漏光）
	float ang = acos(clamp(dot(rd, normalize(sun_dir)), -1.0, 1.0));
	float r = sun_size * (1.0 + (noise(rd.xy * 60.0) - 0.5) * 0.25);
	if (ang < r) {
		col = vec3(0.012, 0.012, 0.02);  // 黑圆（日食遮挡）
	} else if (ang < r * (1.0 + ring_ratio)) {
		float t = (ang - r) / (r * ring_ratio);
		col += sun_tint.rgb * pow(1.0 - t, 3.0) * sun_energy * glow;
	}
	// 外层日冕（极淡）
	if (ang > r * (1.0 + ring_ratio) && ang < r * (1.0 + ring_ratio) + 0.04) {
		float t = (ang - r * (1.0 + ring_ratio)) / 0.04;
		col += sun_tint.rgb * pow(1.0 - t, 4.0) * sun_energy * glow * 0.15;
	}

	COLOR = vec4(col, 1.0);
}
