shader_type canvas_item;

uniform vec4 border_color : source_color = vec4(0.5, 0.5, 0.5, 1.0);
uniform float border_width : hint_range(1.0, 10.0) = 2.0;
uniform vec2 rect_size = vec2(384.0, 256.0);
uniform float time_scale : hint_range(0.1, 2.0) = 0.5;
uniform float saturation : hint_range(0.0, 1.0) = 0.5;
uniform float flow_strength : hint_range(0.5, 5.0) = 2.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float smooth_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash(i), hash(i + vec2(1,0)), f.x),
		mix(hash(i + vec2(0,1)), hash(i + vec2(1,1)), f.x),
		f.y
	);
}

float fbm(vec2 p) {
	float v = 0.0, a = 0.5;
	for (int i = 0; i < 3; i++) {
		v += a * smooth_noise(p);
		p *= 2.0;
		a *= 0.5;
	}
	return v;
}

void fragment() {
	float t = TIME * time_scale;
	
	float dist_left   = UV.x * rect_size.x;
	float dist_right  = (1.0 - UV.x) * rect_size.x;
	float dist_top    = UV.y * rect_size.y;
	float dist_bottom = (1.0 - UV.y) * rect_size.y;
	float min_dist = min(min(dist_left, dist_right), min(dist_top, dist_bottom));
	if (min_dist <= border_width) { COLOR = border_color; } else {
		
		// 主流动方向向右下
		vec2 flow = vec2(t * 0.3, t * 0.15);
		
		// 多层扭曲流纹
		float n1 = fbm(UV * 3.0 + flow);
		float n2 = fbm(UV * 6.0 - flow * 0.7);
		
		// 流线方向扭曲
		vec2 distort = vec2(n1 - 0.5, n2 - 0.5) * flow_strength * 0.08;
		float pattern = fbm(UV * 4.0 + distort + flow * 0.5);
		
		// 高对比度流纹
		float streak = abs(pattern - 0.5) * 2.0;
		streak = smoothstep(0.3, 1.0, streak);
		
		// 颜色：深蓝→青→淡白
		float brightness = streak * 0.7 + 0.3;
		vec3 deep  = vec3(0.02, 0.08, 0.22);
		vec3 mid   = vec3(0.04, 0.18, 0.38);
		vec3 light = vec3(0.15, 0.35, 0.55);
		vec3 col = mix(mix(deep, mid, brightness), light, streak);
		
		// 饱和度插值
		vec3 gray = mix(vec3(0.06), vec3(0.4), brightness);
		col = mix(gray, col, saturation);
		
		COLOR = vec4(col, 0.9);
	}
}
