shader_type canvas_item;

uniform float glow : hint_range(0.0, 2.5) = 1.0;
uniform vec4 ring_color : source_color = vec4(0.92, 0.93, 0.95, 1.0);
uniform float radius = 0.26;
uniform float edge_rough = 0.06;  // 黑圆边缘不规则度（"不那么规则的黑色圆"）

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
	vec2 uv = UV - 0.5;
	float d = length(uv);
	// 不规则黑圆边缘（noise 扰动，随 glow 轻微涨缩：日食加重时黑圆略大）
	float r = radius + (noise(uv * 14.0) - 0.5) * edge_rough * 2.0 + (1.0 - glow) * 0.008;
	float soft = 0.035;  // 黑圆柔边过渡
	vec3 col = vec3(0.0);
	float a = 0.0;
	if (d < r - soft) {
		// 黑圆：极暗带一点冷蓝（日食遮挡）
		col = vec3(0.02, 0.02, 0.04);
		a = 1.0;
	} else if (d < r) {
		// 黑圆柔边过渡（避免硬切）
		float tt = (d - (r - soft)) / soft;
		col = mix(vec3(0.02, 0.02, 0.04), ring_color.rgb * glow * 0.55, tt);
		a = mix(1.0, glow * 0.75, tt);
	} else {
		// 亮环：径向指数衰减（内亮外暗，天然晕开）
		float t = clamp((d - r) / 0.3, 0.0, 1.0);
		float intensity = pow(1.0 - t, 3.0);
		col = ring_color.rgb * intensity * glow * 1.15;
		a = intensity * glow;
	}
	// 外层日冕（极淡大范围光晕）
	if (d > r && d < r + 0.55) {
		float ct = 1.0 - (d - r) / 0.55;
		col += ring_color.rgb * pow(ct, 4.0) * glow * 0.22;
		a += pow(ct, 4.0) * glow * 0.15;
	}
	COLOR = vec4(col, clamp(a, 0.0, 1.0));
}
