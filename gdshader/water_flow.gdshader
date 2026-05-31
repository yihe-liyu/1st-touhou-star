shader_type canvas_item;

uniform vec4 border_color : source_color = vec4(0.5, 0.5, 0.5, 1.0);
uniform float border_width : hint_range(1.0, 10.0) = 2.0;
uniform vec2 rect_size = vec2(384.0, 256.0);

uniform float time_scale : hint_range(0.1, 2.0) = 0.4;
uniform float memory : hint_range(-100.0, 200.0) = 50.0;
uniform float wind_strength : hint_range(0.0, 1.0) = 0.4;
uniform float surge_strength : hint_range(0.0, 1.0) = 0.6;
uniform float wave_angle : hint_range(0.0, 6.2832) = 0.0;
uniform float rot_speed : hint_range(-0.5, 0.5) = 0.05;

// ── 噪声 ──
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float noise(vec2 uv) {
	vec2 i = floor(uv);
	vec2 f = fract(uv);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i+vec2(1,0)), f.x),
	           mix(hash(i+vec2(0,1)), hash(i+vec2(1,1)), f.x), f.y);
}

float fbm(vec2 uv) {
	float val = 0.0;
	float amp = 0.5;
	float freq = 1.0;
	for (int i = 0; i < 4; i++) {
		val += amp * noise(uv * freq);
		freq *= 2.1;
		amp *= 0.55;
	}
	return val;
}

void fragment() {
	// ── 边框 ──
	float dl = UV.x * rect_size.x, dr = (1.0 - UV.x) * rect_size.x;
	float dt = UV.y * rect_size.y, db = (1.0 - UV.y) * rect_size.y;
	if (min(min(dl, dr), min(dt, db)) <= border_width) {
		COLOR = border_color;
	} else {

	// ── memory 驱动项 ──
	float mem_speed  = smoothstep(-100.0, 200.0, memory);
	float mem_sat    = smoothstep(-100.0, 100.0, memory);
	float mem_bright = smoothstep(-100.0, 200.0, memory);
	float mem_frozen = step(memory, -99.0);

	float t = mem_frozen > 0.5 ? 0.0 : TIME * time_scale;

	// ── 旋转 ──
	float a = wave_angle + TIME * rot_speed;
	vec2 centered = UV - 0.5;
	vec2 ruv = vec2(centered.x*cos(a) - centered.y*sin(a),
	                centered.x*sin(a) + centered.y*cos(a)) + 0.5;
	vec2 uv = ruv * 3.0;

	// ── FBM 波浪 ──
	float s = 1.0 + mem_speed * 0.6; // 波幅随 memory 增强
	float wave1 = fbm(uv * 4.0 + vec2(t*0.3, t*0.25)) * s;
	float wave2 = fbm(uv * 5.5 + vec2(-t*0.25, t*0.35)) * s * 0.7;
	float wave = (wave1 + wave2) - 0.85; // → -1~1 范围

	float normalized = clamp(wave * 0.5 + 0.5, 0.0, 1.0);

	// 削尖波峰
	float crest = normalized;
	if (normalized > 0.5) {
		crest = 0.5 + pow((normalized - 0.5) * 2.0, 3.0) * 0.5;
	} else {
		crest = pow(normalized * 2.0, 0.7) * 0.5;
	}

	// ── 颜色 ──
	vec3 abyss  = vec3(0.005, 0.04, 0.14);
	vec3 deep   = vec3(0.02, 0.10, 0.25);
	vec3 mid    = vec3(0.06, 0.18, 0.35);
	vec3 shore  = vec3(0.12, 0.26, 0.42);
	vec3 foam_col = vec3(0.70, 0.80, 0.88);

	vec3 col;
	float d = crest;
	if (d < 0.3)       col = mix(abyss, deep,  d / 0.3);
	else if (d < 0.6)  col = mix(deep,  mid,   (d-0.3)/0.3);
	else if (d < 0.85) col = mix(mid,   shore, (d-0.6)/0.25);
	else                col = shore;

	// 泡沫：波峰 + 噪声纹理
	float foam_noise = fbm(uv * 25.0 + t * 0.6);
	float foam_anim = smoothstep(0.4, 0.8, foam_noise);
	float foam_mask = smoothstep(0.7, 0.92, crest) * foam_anim * 0.9;
	col = mix(col, foam_col, foam_mask);

	// 高光
	float spec = smoothstep(0.55, 0.78, crest) * (1.0 - foam_mask);
	col += spec * 0.07 * vec3(0.3, 0.5, 0.72);

	// ── 风痕 ──
	vec2 wuv = vec2(uv.x * 0.6, uv.y * 3.0);
	float wn1 = noise(wuv + vec2(t*0.4, t*0.1));
	float wn2 = noise(vec2(wuv.x*2.5 + t*0.6, wuv.y*0.3)) * 0.5 + 0.5;
	float wind = smoothstep(0.55, 0.72, wn1*wn2) * (1.0 - pow(wn1, 3.0)) * wind_strength;
	col = mix(col, col*1.3 + vec3(0.06, 0.10, 0.16), wind);

	// ── 暗涌 ──
	vec2 suv = uv * 1.6;
	float surge1 = fbm(suv * 2.0 + t * 0.15);
	float surge2 = fbm(suv * 2.8 - t * 0.12) * 0.6;
	float surge = (surge1 + surge2 - 0.8) * surge_strength;
	float sd = surge * 0.5 + 0.5;
	col = mix(col*0.65, col*1.12 + vec3(0.02, 0.05, 0.10), sd);

	// ── 彩色插值（memory 驱动） ──
	float hue = fract(wave1*0.7 + wave2*0.5 + t*0.03);
	vec3 colorful;
	if (hue < 0.2)      colorful = mix(vec3(0.06,0.10,0.45), vec3(0.03,0.26,0.48), hue/0.2);
	else if (hue < 0.4) colorful = mix(vec3(0.03,0.26,0.48), vec3(0.06,0.40,0.42), (hue-0.2)/0.2);
	else if (hue < 0.6) colorful = mix(vec3(0.06,0.40,0.42), vec3(0.30,0.36,0.14), (hue-0.4)/0.2);
	else if (hue < 0.8) colorful = mix(vec3(0.30,0.36,0.14), vec3(0.42,0.18,0.14), (hue-0.6)/0.2);
	else                 colorful = mix(vec3(0.42,0.18,0.14), vec3(0.32,0.08,0.28), (hue-0.8)/0.2);

	vec3 gray = mix(vec3(0.05), vec3(0.4), crest);
	col = mix(gray, mix(col, colorful, mem_sat), mem_sat);

	// ── 亮度 ──
	col = max(col, 0.0);
	col *= mix(0.3, 1.6, mem_bright);

	COLOR = vec4(col, 0.92);
	}
}
