shader_type canvas_item;

uniform vec4 border_color : source_color = vec4(0.5, 0.5, 0.5, 1.0);
uniform float border_width : hint_range(1.0, 10.0) = 2.0;
uniform vec2 rect_size = vec2(384.0, 256.0);
uniform float time_scale : hint_range(0.1, 5.0) = 1.0;
uniform float wave_strength : hint_range(0.1, 1.0) = 0.5;
uniform float flow_speed : hint_range(0.1, 3.0) = 0.8;
uniform float saturation : hint_range(0.0, 1.0) = 0.5;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	float t = TIME * time_scale;
	
	float dist_left   = UV.x * rect_size.x;
	float dist_right  = (1.0 - UV.x) * rect_size.x;
	float dist_top    = UV.y * rect_size.y;
	float dist_bottom = (1.0 - UV.y) * rect_size.y;
	float min_dist = min(min(dist_left, dist_right), min(dist_top, dist_bottom));
	
	if (min_dist <= border_width) {
		COLOR = border_color;
	} else {
		float wave1 = noise(UV * 8.0 + vec2(t * flow_speed, t * 0.3));
		float wave2 = noise(UV * 16.0 - vec2(t * 0.5, t * flow_speed));
		float wave3 = noise(UV * 32.0 + vec2(t * 0.7, -t * 0.6));
		float wave = wave1 * 0.5 + wave2 * 0.3 + wave3 * 0.2;
		
		// 波纹扭曲 UV
		vec2 wuv = UV + vec2((wave1 - 0.5) * wave_strength, (wave2 - 0.5) * wave_strength);
		float w1 = noise(wuv * 8.0);
		float w2 = noise(wuv * 16.0);
		float w3 = noise(wuv * 32.0);
		float w = w1 * 0.5 + w2 * 0.3 + w3 * 0.2;
		
		float depth = w * 0.6 + 0.4;
		vec3 gray = mix(vec3(0.08), vec3(0.45), depth);
		
		// 极光色带——靛→青→金→玫，随波流转
		float t_col = fract(w1 * 2.0 + w2 * 0.7 + t * 0.05);
		vec3 col;
		if (t_col < 0.25)
			col = mix(vec3(0.08, 0.05, 0.28), vec3(0.04, 0.22, 0.48), t_col / 0.25);
		else if (t_col < 0.5)
			col = mix(vec3(0.04, 0.22, 0.48), vec3(0.12, 0.38, 0.42), (t_col - 0.25) / 0.25);
		else if (t_col < 0.75)
			col = mix(vec3(0.12, 0.38, 0.42), vec3(0.38, 0.28, 0.15), (t_col - 0.5) / 0.25);
		else
			col = mix(vec3(0.38, 0.28, 0.15), vec3(0.3, 0.12, 0.22), (t_col - 0.75) / 0.25);
		col = mix(vec3(0.06), col, depth);
		
		vec3 water_color = mix(gray, col, saturation);
		
		float highlight = smoothstep(0.6, 0.8, w) * 0.2;
		water_color += highlight * mix(vec3(0.12), vec3(0.22), saturation);
		
		COLOR = vec4(water_color, 0.85);
	}
}
