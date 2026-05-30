shader_type canvas_item;

uniform vec4 border_color : source_color = vec4(0.5, 0.5, 0.5, 1.0);
uniform float border_width : hint_range(1.0, 10.0) = 2.0;
uniform vec2 rect_size = vec2(384.0, 256.0);
uniform float time_scale : hint_range(0.1, 2.0) = 0.6;
uniform float saturation : hint_range(0.0, 1.0) = 0.5;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1,0)), f.x),
	           mix(hash(i + vec2(0,1)), hash(i + vec2(1,1)), f.x), f.y);
}

void fragment() {
	float t = TIME * time_scale;
	
	float dl = UV.x * rect_size.x, dr = (1.0 - UV.x) * rect_size.x;
	float dt = UV.y * rect_size.y, db = (1.0 - UV.y) * rect_size.y;
	float min_dist = min(min(dl, dr), min(dt, db));
	if (min_dist <= border_width) { COLOR = border_color; } else {
		
		vec2 uv = UV * 2.5;
		
		// ── 涌浪层（大尺度） ──
		float swell1 = sin(uv.x * 2.0 + t * 0.9) * 0.5;
		float swell2 = sin(uv.x * 3.3 - t * 0.65 + 1.5) * 0.3;
		float swell3 = cos(uv.y * 1.5 + t * 0.4) * 0.2;
		
		// ── 涟漪层（中尺度） ──
		float ripple1 = sin(uv.x * 6.0 + uv.y * 3.0 + t * 1.3) * 0.12;
		float ripple2 = cos(uv.x * 4.5 - uv.y * 5.0 + t * 0.8) * 0.1;
		float ripple3 = sin(uv.x * 8.0 + t * 1.0) * cos(uv.y * 7.0 + t * 0.7) * 0.08;
		
		// ── 微纹理（小尺度噪声） ──
		float micro = (noise(uv * 12.0 + t * 0.3) - 0.5) * 0.04;
		float micro2 = (noise(uv * 20.0 - t * 0.2) - 0.5) * 0.03;
		
		float wave = swell1 + swell2 + swell3 + ripple1 + ripple2 + ripple3 + micro + micro2;
		float normalized = wave * 0.5 + 0.5;
		
		// ── 浪形：削尖波峰，圆润波谷 ──
		float crest = normalized;
		if (normalized > 0.5) {
			crest = 0.5 + pow((normalized - 0.5) * 2.0, 2.5) * 0.5;
		} else {
			crest = pow(normalized * 2.0, 0.7) * 0.5;
		}
		
		// ── 颜色 ──
		vec3 abyss  = vec3(0.005, 0.03, 0.12);
		vec3 deep   = vec3(0.015, 0.07, 0.22);
		vec3 mid    = vec3(0.04, 0.16, 0.36);
		vec3 shore  = vec3(0.1, 0.24, 0.44);
		vec3 foam_col = vec3(0.65, 0.78, 0.88);
		
		float depth = crest;
		vec3 col;
		if (depth < 0.25)      col = mix(abyss, deep,  depth / 0.25);
		else if (depth < 0.55) col = mix(deep,  mid,   (depth - 0.25) / 0.3);
		else if (depth < 0.8)  col = mix(mid,   shore, (depth - 0.55) / 0.25);
		else                    col = shore;
		
		// ── 浪尖泡沫（带噪声纹理） ──
		float foam_noise = noise(uv * 15.0 + t * 0.5) * 0.3 + 0.7;
		float foam_mask = smoothstep(0.78, 0.92, crest) * foam_noise;
		col = mix(col, foam_col, foam_mask * 0.8);
		
		// ── 泡沫拖尾 ──
		float trail = smoothstep(0.7, 0.82, crest) * smoothstep(0.85, 0.75, crest + 0.05);
		float trail_noise = noise(uv * 8.0 - t * 0.6) * 0.5 + 0.5;
		col = mix(col, foam_col, trail * trail_noise * 0.2);
		
		// ── 反光 ──
		float spec = smoothstep(0.55, 0.75, crest) * (1.0 - foam_mask);
		col += spec * 0.08 * vec3(0.3, 0.5, 0.7);
		
		// ── 水面下的暗纹 ──
		float dark_streak = (noise(uv * 5.0 - t * 0.15) - 0.5) * 0.06;
		col += dark_streak * (1.0 - crest);
		
		// ── 饱和度 ──
		vec3 gray = mix(vec3(0.05), vec3(0.4), crest);
		col = mix(gray, col, saturation);
		
		COLOR = vec4(col, 0.92);
	}
}
