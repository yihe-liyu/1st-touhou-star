shader_type canvas_item;

uniform vec4 border_color : source_color = vec4(0.5, 0.5, 0.5, 1.0);
uniform float border_width : hint_range(1.0, 10.0) = 2.0;
uniform vec2 rect_size = vec2(384.0, 256.0);
uniform float time_scale : hint_range(1.0, 3.0) = 0.4;
uniform float memory : hint_range(-100.0, 200.0) = 50.0;
uniform float wind_strength : hint_range(0.0, 1.0) = 0.4;
uniform float surge_strength : hint_range(0.0, 1.0) = 0.6;
uniform float wave_angle : hint_range(0.0, 6.2832) = 0.0;
uniform float rot_speed : hint_range(-0.5, 0.5) = 0.05;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i+vec2(1,0)), f.x), mix(hash(i+vec2(0,1)), hash(i+vec2(1,1)), f.x), f.y);
}

void fragment() {
	float dl = UV.x * rect_size.x, dr = (1.0 - UV.x) * rect_size.x;
	float dt = UV.y * rect_size.y, db = (1.0 - UV.y) * rect_size.y;
	float min_dist = min(min(dl, dr), min(dt, db));
	if (min_dist <= border_width) { COLOR = border_color; } else {
		
		// ── memory 驱动项 ──
		float mem_speed   = smoothstep(-100.0, 200.0, memory);  // 0→1 波幅
		float mem_boost   = 1.0 + mem_speed;              // 1x→2x 涌浪增强
		float mem_sat     = smoothstep(-100.0, 100.0, memory);  // 彩度
		float mem_bright  = smoothstep(-100.0, 200.0, memory);  // 亮度
		float mem_frozen  = step(memory, -99.0);               // -100 冻结
		
		float t = TIME * time_scale;
		if (mem_frozen > 0.5) t = 0.0;  // 冻结时停时间
		
		// 旋转浪向
		float a = wave_angle + TIME * rot_speed;
		vec2 centered = UV - 0.5;
		vec2 ruv = vec2(centered.x*cos(a) - centered.y*sin(a), centered.x*sin(a) + centered.y*cos(a)) + 0.5;
		vec2 uv = ruv * 2.5;
		
		// ── 涌浪 ──
		float swell1 = sin(uv.x*2.0 + t*0.9) * 0.5 * mem_speed * mem_boost;
		float swell2 = sin(uv.x*3.3 - t*0.65 + 1.5) * 0.3 * mem_speed * mem_boost;
		float swell3 = cos(uv.y*1.5 + t*0.4) * 0.2 * mem_speed * mem_boost;
		
		// ── 涟漪 ──
		float ripple1 = sin(uv.x*6.0 + uv.y*3.0 + t*1.3) * 0.12 * mem_speed;
		float ripple2 = cos(uv.x*4.5 - uv.y*5.0 + t*0.8) * 0.1 * mem_speed;
		float ripple3 = sin(uv.x*8.0 + t*1.0) * cos(uv.y*7.0 + t*0.7) * 0.08 * mem_speed;
		
		float micro = (noise(uv*12.0 + t*0.3) - 0.5) * 0.04 * mem_speed;
		float micro2 = (noise(uv*20.0 - t*0.2) - 0.5) * 0.03 * mem_speed;
		
		float wave = swell1+swell2+swell3 + ripple1+ripple2+ripple3 + micro+micro2;
		float normalized = clamp(wave*0.5 + 0.5, 0.0, 1.0);
		
		float crest = normalized;
		if (normalized > 0.5) crest = 0.5 + pow((normalized-0.5)*2.0, 2.5)*0.5;
		else crest = pow(normalized*2.0, 0.7)*0.5;
		
		vec3 abyss = vec3(0.005,0.03,0.12), deep = vec3(0.015,0.07,0.22);
		vec3 mid = vec3(0.04,0.16,0.36), shore = vec3(0.1,0.24,0.44);
		vec3 foam_col = vec3(0.65,0.78,0.88);
		
		float depth = crest;
		vec3 col;
		if (depth<0.25) col=mix(abyss,deep,depth/0.25);
		else if (depth<0.55) col=mix(deep,mid,(depth-0.25)/0.3);
		else if (depth<0.8) col=mix(mid,shore,(depth-0.55)/0.25);
		else col=shore;
		
		float foam_noise = noise(uv*15.0 + t*0.5)*0.3+0.7;
		float foam_mask = smoothstep(0.78,0.92,crest)*foam_noise;
		col = mix(col, foam_col, foam_mask*0.8);
		
		float trail = smoothstep(0.7,0.82,crest)*smoothstep(0.85,0.75,crest+0.05);
		float trail_noise = noise(uv*8.0 - t*0.6)*0.5+0.5;
		col = mix(col, foam_col, trail*trail_noise*0.2);
		
		float spec = smoothstep(0.55,0.75,crest)*(1.0-foam_mask);
		col += spec*0.08*vec3(0.3,0.5,0.7);
		
		float dark_streak = (noise(uv*5.0 - t*0.15)-0.5)*0.06;
		col += dark_streak*(1.0-crest);
		
		vec2 wuv = vec2(uv.x*0.8, uv.y*3.5);
		float wn1 = noise(wuv + vec2(t*0.4, t*0.1));
		float wn2 = noise(vec2(wuv.x*3.0 + t*0.7, wuv.y*0.3))*0.6+0.4;
		float wind = smoothstep(0.55,0.7, wn1*wn2)*(1.0-pow(wn1,3.0))*wind_strength;
		col = mix(col, col*1.4+vec3(0.08,0.12,0.18), wind);
		
		vec2 surge_uv = uv*1.8;
		float surge1 = sin(surge_uv.x*2.0 + surge_uv.y*1.3 + t*0.3)*0.5;
		float surge2 = cos(surge_uv.x*1.4 - surge_uv.y*1.7 + t*0.25)*0.3;
		float surge_noise = noise(surge_uv*3.0 + t*0.15);
		float surge = (surge1+surge2)*surge_noise*surge_strength;
		float surge_depth = surge*0.5+0.5;
		col = mix(col*0.6, col*1.15+vec3(0.02,0.04,0.08), surge_depth);
		
		float hue = fract(swell1*0.7 + swell2*0.5 + ripple1*0.3 + t*0.03);
		vec3 colorful;
		if (hue<0.2) colorful=mix(vec3(0.06,0.12,0.45),vec3(0.03,0.28,0.5),hue/0.2);
		else if (hue<0.4) colorful=mix(vec3(0.03,0.28,0.5),vec3(0.08,0.42,0.45),(hue-0.2)/0.2);
		else if (hue<0.6) colorful=mix(vec3(0.08,0.42,0.45),vec3(0.32,0.38,0.15),(hue-0.4)/0.2);
		else if (hue<0.8) colorful=mix(vec3(0.32,0.38,0.15),vec3(0.45,0.2,0.15),(hue-0.6)/0.2);
		else colorful=mix(vec3(0.45,0.2,0.15),vec3(0.35,0.1,0.3),(hue-0.8)/0.2);
		
		vec3 gray = mix(vec3(0.05), vec3(0.4), crest);
		col = mix(gray, mix(col, colorful, mem_sat), mem_sat);
		col = max(col, 0.0);
		col *= mix(0.3, 1.6, mem_bright);
		
		COLOR = vec4(col, 0.92);
	}
}
