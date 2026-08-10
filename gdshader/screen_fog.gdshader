shader_type canvas_item;
render_mode blend_mix;

// ── 氛围合并 pass：全局调色 + 蒙眼雾 + 渐晕 + 日食漏光 ──
// 全屏不透明层：取屏幕底色 → 调色 → 蒙眼雾压暗 → 太阳处浓雾 → 边缘渐晕 → 漏光亮环
// 一个 pass 顶原来的雾层 + 调色层（E+G 合并）

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform sampler2D noise_tex;

// ── 蒙眼雾 ──
uniform float fog_dark : hint_range(0.0, 1.0) = 0.5;
uniform vec2 sun_pos = vec2(0.5, 0.18);
uniform float sun_fog_radius : hint_range(0.0, 0.5) = 0.16;
uniform float sun_fog_extra : hint_range(0.0, 1.0) = 0.45;
uniform float flow_speed : hint_range(0.0, 0.5) = 0.03;
uniform float noise_scale = 1.4;
uniform vec3 fog_color : source_color = vec3(0.02, 0.02, 0.03);
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.4;   // 边缘渐晕（蒙眼感）
uniform float breath_speed : hint_range(0.0, 1.0) = 0.18;       // 呼吸感
uniform float rim_strength : hint_range(0.0, 1.0) = 0.35;       // 日食漏光亮环强度
uniform vec3 rim_color : source_color = vec3(1.0, 0.82, 0.56);  // 漏光暖色

// ── 全局调色 ──
uniform float grade_brightness : hint_range(0.0, 2.0) = 1.0;
uniform float grade_contrast : hint_range(0.0, 2.0) = 1.06;
uniform float grade_saturation : hint_range(0.0, 2.0) = 0.88;
uniform vec3 grade_lift : source_color = vec3(0.008, 0.011, 0.02);  // 暗部偏冷蓝
uniform vec3 grade_gamma : source_color = vec3(1.0);
uniform vec3 grade_gain : source_color = vec3(1.0, 0.975, 0.93);    // 亮部偏暖

void fragment() {
	// ① 取屏幕底色（3D 背景 + 辉光后的结果）
	vec3 col = texture(screen_tex, SCREEN_UV).rgb;

	// ② 全局调色：亮度 → 对比度 → 饱和度 → lift/gamma/gain
	col *= grade_brightness;
	col = (col - 0.5) * grade_contrast + 0.5;
	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(luma), col, grade_saturation);
	col = (col - grade_lift) / max(grade_gamma, vec3(0.001));
	col *= grade_gain;
	col = clamp(col, 0.0, 1.0);

	// ③ 蒙眼雾：双层噪声（不同频率/流向）→ 有机漂移 + 呼吸
	float breath = 1.0 + 0.05 * sin(TIME * breath_speed);
	vec2 q1 = UV * noise_scale + vec2(TIME * flow_speed, TIME * flow_speed * 0.7);
	vec2 q2 = UV * noise_scale * 2.0 + vec2(-TIME * flow_speed * 0.55, TIME * flow_speed * 0.9);
	float n1 = texture(noise_tex, fract(q1)).r;
	float n2 = texture(noise_tex, fract(q2)).g;
	float n = mix(n1, n2, 0.45);
	float fog = fog_dark * breath * (0.55 + 0.45 * n);

	// ④ 太阳浓雾：噪声扰动半径 → 不规则羽化边缘
	float ds = distance(UV, sun_pos);
	float rr = sun_fog_radius * (1.0 + 0.35 * (n1 - 0.5) * 2.0);
	float edge = smoothstep(rr, rr * 0.3, ds);  // 圆内浓，向外羽化
	fog += sun_fog_extra * edge * (0.55 + 0.45 * n2);

	// ⑤ 渐晕：蒙眼边缘更暗
	float vg = smoothstep(0.28, 0.82, distance(UV, vec2(0.5)));
	fog += vg * vignette_strength * 0.42;

	fog = clamp(fog, 0.0, 0.92);

	// ⑥ 漏光亮环：日食边缘漏出的暖光（微微呼吸）
	float rim = exp(-pow((ds - rr) / max(rr * 0.55, 0.02), 2.0));
	rim *= rim_strength * (0.75 + 0.25 * sin(TIME * 0.7));

	// ⑦ 合成：暗雾打底 + 暖漏光
	vec3 out_col = col * (1.0 - fog) + fog_color * fog;
	out_col = mix(out_col, rim_color, rim * (1.0 - fog));
	COLOR = vec4(out_col, 1.0);
}
