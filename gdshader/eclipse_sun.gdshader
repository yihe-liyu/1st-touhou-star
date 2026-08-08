shader_type canvas_item;
// 摄像机平面黑圆遮罩（伪日食）——盖住 3D 太阳光斑中心，露边缘漏光
// glow：击破回光时漏光增强

uniform float glow : hint_range(0.0, 2.5) = 1.0;
uniform vec4 ring_color : source_color = vec4(0.92, 0.95, 1.0, 1.0);
uniform float radius : hint_range(0.1, 0.5) = 0.30;   // 黑圆半径（UV）

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
	// 不规则黑圆边缘（noise 扰动）
	float r = radius * (1.0 + (noise(uv * 30.0) - 0.5) * 0.18);
	vec3 col = vec3(0.0);
	float a = 0.0;
	if (d < r) {
		col = vec3(0.012, 0.012, 0.02);
		a = 1.0;
	} else if (d < r * 1.35) {
		// 边缘漏光（指数衰减）
		float t = (d - r) / (r * 0.35);
		col = ring_color.rgb * pow(1.0 - t, 3.0) * glow;
		a = pow(1.0 - t, 2.0) * glow;
	}
	COLOR = vec4(col, clamp(a, 0.0, 1.0));
}
