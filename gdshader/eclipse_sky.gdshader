shader_type sky;
// 伪日食天空（此 fork 的 sky shader 内置：EYEDIR 视线方向 / LIGHT0_* 太阳 / COLOR 输出）
// 太阳方向由 DirectionalLight3D（sky_mode=LIGHT_AND_SKY）提供

uniform vec4 sun_tint : source_color = vec4(0.92, 0.95, 1.0, 1.0);
uniform float sun_energy : hint_range(0.0, 4.0) = 2.2;
uniform float sun_size : hint_range(0.01, 0.06) = 0.022;    // 黑圆角半径（弧度）
uniform float ring_ratio : hint_range(0.0, 1.0) = 0.55;     // 漏光环宽度（相对黑圆）
uniform float glow : hint_range(0.0, 2.5) = 1.0;            // 击破回光：漏光增强

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
	vec3 rd = normalize(EYEDIR);
	// 天色：地平线稍亮、天顶暗（压抑）
	float h = clamp(rd.y, 0.0, 1.0);
	vec3 col = mix(vec3(0.20, 0.21, 0.25), vec3(0.08, 0.09, 0.12), pow(h, 0.55));
	if (rd.y < 0.0) {
		col = mix(vec3(0.05, 0.05, 0.07), vec3(0.20, 0.21, 0.25), clamp(-rd.y, 0.0, 1.0) * 0.6);
	}
	// 太阳（LIGHT0_DIRECTION = 太阳方向；DirectionalLight3D.sky_mode 驱动）
	if (LIGHT0_ENABLED) {
		float ang = acos(clamp(dot(rd, normalize(LIGHT0_DIRECTION)), -1.0, 1.0));
		float r = sun_size * (1.0 + (noise(rd.xy * 60.0) - 0.5) * 0.25);
		if (ang < r) {
			// 黑圆（日食遮挡）
			col = vec3(0.012, 0.012, 0.02);
		} else if (ang < r * (1.0 + ring_ratio)) {
			// 边缘漏光：指数衰减亮环
			float t = (ang - r) / (r * ring_ratio);
			col += sun_tint.rgb * LIGHT0_COLOR.rgb * pow(1.0 - t, 3.0) * LIGHT0_ENERGY * sun_energy * glow;
		}
	}
	COLOR = vec4(col, 1.0);
}
