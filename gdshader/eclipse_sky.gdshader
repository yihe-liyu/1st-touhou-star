shader_type sky;
// 伪日食天空：暗色天色 + 清晰太阳圆斑 + 黑圆遮罩（边缘漏光）
// RAY_DIR = 当前像素的世界方向（真 3D 天空：相机转向时太阳固定在天上）

uniform vec4 sun_color : source_color = vec4(0.92, 0.95, 1.0, 1.0);
uniform float sun_energy : hint_range(0.0, 4.0) = 2.2;
uniform float sun_size : hint_range(0.005, 0.06) = 0.018;   // 黑圆角半径（弧度）
uniform float ring_ratio : hint_range(0.0, 1.0) = 0.5;      // 漏光环宽度（相对黑圆）
uniform vec3 sun_direction = vec3(-0.35, 0.14, -0.92);      // 左前上方地平线附近
uniform float glow : hint_range(0.0, 2.5) = 1.0;            // 击破后回光：漏光增强

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
	vec3 rd = normalize(RAY_DIR);
	// 天色：地平线稍亮、天顶暗（压抑）
	float h = clamp(rd.y, 0.0, 1.0);
	vec3 col = mix(vec3(0.20, 0.21, 0.25), vec3(0.08, 0.09, 0.12), pow(h, 0.55));
	// 地平线下（地面方向）更暗
	if (rd.y < 0.0) {
		col = mix(vec3(0.05, 0.05, 0.07), vec3(0.20, 0.21, 0.25), clamp(-rd.y, 0.0, 1.0) * 0.6);
	}

	float ang = acos(clamp(dot(rd, sun_direction), -1.0, 1.0));
	float ring = sun_size * (1.0 + ring_ratio);
	// 黑圆（日食遮挡，noise 扰动边缘）
	float r = sun_size * (1.0 + (noise(rd.xy * 60.0) - 0.5) * 0.25);
	if (ang < r) {
		col = vec3(0.012, 0.012, 0.02);
	} else if (ang < ring) {
		// 边缘漏光：指数衰减亮环
		float t = (ang - r) / (ring - r);
		col += sun_color.rgb * pow(1.0 - t, 3.0) * sun_energy * glow;
	}
	// 外层日冕（极淡）
	if (ang > ring && ang < ring + 0.04) {
		float t = (ang - ring) / 0.04;
		col += sun_color.rgb * pow(1.0 - t, 4.0) * sun_energy * glow * 0.15;
	}

	COLOR = vec4(col, 1.0);
}
