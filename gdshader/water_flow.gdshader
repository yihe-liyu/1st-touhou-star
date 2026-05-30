shader_type canvas_item;

uniform vec4 border_color : source_color = vec4(0.5, 0.5, 0.5, 1.0);
uniform float border_width : hint_range(1.0, 10.0) = 2.0;
uniform vec2 rect_size = vec2(384.0, 256.0);
uniform float time_scale : hint_range(0.1, 5.0) = 1.0;
uniform float wave_strength : hint_range(0.01, 0.1) = 0.03;
uniform float flow_speed : hint_range(0.1, 3.0) = 0.8;

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
	
	// ── 边框 ──
	float dist_left   = UV.x * rect_size.x;
	float dist_right  = (1.0 - UV.x) * rect_size.x;
	float dist_top    = UV.y * rect_size.y;
	float dist_bottom = (1.0 - UV.y) * rect_size.y;
	float min_dist = min(min(dist_left, dist_right), min(dist_top, dist_bottom));
	
	if (min_dist <= border_width) {
		COLOR = border_color;
		return;
	}
	
	// ── 水面 ──
	float wave1 = noise(UV * 8.0 + vec2(t * flow_speed, t * 0.3));
	float wave2 = noise(UV * 16.0 - vec2(t * 0.5, t * flow_speed));
	float wave3 = noise(UV * 32.0 + vec2(t * 0.7, -t * 0.6));
	float wave = wave1 * 0.5 + wave2 * 0.3 + wave3 * 0.2;
	
	vec3 deep    = vec3(0.05, 0.15, 0.35);
	vec3 shallow = vec3(0.1, 0.35, 0.55);
	float depth = wave * 0.6 + 0.4;
	vec3 water_color = mix(deep, shallow, depth);
	
	float highlight = smoothstep(0.55, 0.75, wave) * 0.3;
	water_color += highlight * vec3(0.4, 0.6, 0.8);
	
	COLOR = vec4(water_color, 0.85);
}
