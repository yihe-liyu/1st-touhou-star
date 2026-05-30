shader_type canvas_item;

uniform vec4 border_color : source_color = vec4(0.5, 0.5, 0.5, 1.0);
uniform float border_width : hint_range(1.0, 10.0) = 2.0;
uniform vec2 rect_size = vec2(384.0, 256.0);
uniform float time_scale : hint_range(0.1, 2.0) = 0.6;
uniform float saturation : hint_range(0.0, 1.0) = 0.5;

void fragment() {
	float t = TIME * time_scale;
	
	// ── 边框 ──
	float dist_left   = UV.x * rect_size.x;
	float dist_right  = (1.0 - UV.x) * rect_size.x;
	float dist_top    = UV.y * rect_size.y;
	float dist_bottom = (1.0 - UV.y) * rect_size.y;
	float min_dist = min(min(dist_left, dist_right), min(dist_top, dist_bottom));
	if (min_dist <= border_width) { COLOR = border_color; } else {
	
	// ── 多层正弦波叠加 ──
	vec2 uv = UV * 6.0;
	float w1 = sin(uv.x * 2.3 + t * 0.7) * sin(uv.y * 1.7 + t * 0.5);
	float w2 = sin(uv.x * 3.7 - t * 0.6 + 1.2) * sin(uv.y * 2.9 + t * 0.4);
	float w3 = sin(uv.x * 5.1 + t * 0.3) * cos(uv.y * 4.3 - t * 0.55);
	float w4 = sin((uv.x + uv.y) * 4.0 + t * 0.8) * cos((uv.x - uv.y) * 3.5 + t * 0.35);
	
	float height = (w1 * 0.35 + w2 * 0.25 + w3 * 0.2 + w4 * 0.2);
	float normalized = height * 0.5 + 0.5;  // 0~1
	
	// ── 深度色 ──
	vec3 deep  = vec3(0.01, 0.06, 0.2);
	vec3 mid   = vec3(0.02, 0.15, 0.38);
	vec3 shore = vec3(0.05, 0.28, 0.5);
	
	float depth = normalized;
	vec3 col;
	if (depth < 0.5)
		col = mix(deep, mid, depth * 2.0);
	else
		col = mix(mid, shore, (depth - 0.5) * 2.0);
	
	// ── 波峰高光 ──
	float crest = smoothstep(0.7, 0.85, normalized);
	float foam  = smoothstep(0.85, 0.95, normalized) * 0.4;
	col += crest * 0.12 * vec3(0.4, 0.55, 0.7);
	col += foam  * 0.25 * vec3(0.6, 0.75, 0.85);
	
	// ── 饱和度插值 ──
	vec3 gray = mix(vec3(0.06), vec3(0.4), normalized);
	col = mix(gray, col, saturation);
	
	COLOR = vec4(col, 0.88);
	}
}
