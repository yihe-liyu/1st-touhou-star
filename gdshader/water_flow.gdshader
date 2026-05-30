shader_type canvas_item;

uniform vec4 border_color : source_color = vec4(0.5, 0.5, 0.5, 1.0);
uniform float border_width : hint_range(1.0, 10.0) = 2.0;
uniform vec2 rect_size = vec2(384.0, 256.0);
uniform float time_scale : hint_range(0.1, 2.0) = 0.7;
uniform float saturation : hint_range(0.0, 1.0) = 0.5;

void fragment() {
	float t = TIME * time_scale;
	
	float dl = UV.x * rect_size.x, dr = (1.0 - UV.x) * rect_size.x;
	float dt = UV.y * rect_size.y, db = (1.0 - UV.y) * rect_size.y;
	float min_dist = min(min(dl, dr), min(dt, db));
	if (min_dist <= border_width) { COLOR = border_color; } else {
		
		// 大涌浪 — 几组不同频率和方向的大波
		float w1 = sin(UV.x * 4.5 + t * 1.2) * 0.6;
		float w2 = sin(UV.x * 7.0 - t * 0.8 + 2.0) * 0.3;
		float w3 = cos(UV.y * 3.0 + t * 0.5) * 0.2;
		float w4 = sin((UV.x + UV.y * 0.5) * 5.0 + t * 0.6) * 0.15;
		
		float wave = w1 + w2 + w3 + w4;
		float normalized = wave * 0.5 + 0.5;
		
		// ── 浪尖削尖（pow 让波峰更陡） ──
		float crest = pow(normalized, 3.0);
		
		// ── 颜色：深处暗蓝，浅处青绿，浪尖白 ──
		vec3 deep  = vec3(0.01, 0.05, 0.18);
		vec3 mid   = vec3(0.03, 0.14, 0.35);
		vec3 shore = vec3(0.08, 0.22, 0.42);
		vec3 foam  = vec3(0.6, 0.75, 0.85);
		
		float depth = normalized;
		vec3 col;
		if (depth < 0.4)
			col = mix(deep, mid, depth / 0.4);
		else
			col = mix(mid, shore, (depth - 0.4) / 0.6);
		
		// 浪尖泡沫
		float foam_mask = smoothstep(0.75, 0.9, crest);
		col = mix(col, foam, foam_mask * 0.7);
		
		// 浪面高光
		float spec = smoothstep(0.65, 0.8, normalized);
		col += spec * 0.1 * vec3(0.3, 0.45, 0.6);
		
		// 饱和度
		vec3 gray = mix(vec3(0.06), vec3(0.4), normalized);
		col = mix(gray, col, saturation);
		
		COLOR = vec4(col, 0.9);
	}
}
