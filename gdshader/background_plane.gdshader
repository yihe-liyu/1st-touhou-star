shader_type spatial;
render_mode unshaded, fog_disabled;

// fog_disabled：环境雾（黑色）会把远处地面压成黑绿（B=0），与天空蓝灰不衔接 → 地面雾由本 shader 全权控制

uniform sampler2D base_texture : source_color;
uniform vec2 tiling = vec2(6.0);
uniform vec2 uv_offset = vec2(0.0);
uniform vec4 modulate : source_color = vec4(1.0);

// ── 距离雾：近清远朦，远处融进暗雾 ──
uniform vec3 fog_color : source_color = vec3(0.12, 0.13, 0.15);
uniform float fog_density : hint_range(0.0, 0.1) = 0.012;
uniform float fog_start : hint_range(0.0, 200.0) = 55.0;

// ── 平铺扰动：双档噪声随时间缓慢流动，减轻重复感 ──
uniform float perturb_amount : hint_range(0.0, 0.2) = 0.035;
uniform float perturb_freq : hint_range(0.0, 4.0) = 0.9;

// ── 远缘渐隐：最后一段（local z）从暗雾渐变到天球色 → 水平线无缝 ──
// （假设平面深 340：local z 范围 ±170，远缘在 -170；树带最远 -220）
uniform float edge_fade_start : hint_range(-200.0, 0.0) = -120.0;
uniform float edge_fade_end : hint_range(-200.0, 0.0) = -166.0;
// 天球水平线以下颜色（实测 0.29,0.32,0.35）——平面边缘必须融进它才无缝
uniform vec3 edge_fade_color : source_color = vec3(0.29, 0.32, 0.35);

// 相机世界位置（脚本每帧更新）。注意：本项目环境下 fragment 的 VIEW 内置返回 0，
// 所以距离在 vertex 里用 MODEL_MATRIX 手动计算再插值
uniform vec3 cam_pos = vec3(0.0, 10.0, 6.0);

varying float v_dist;

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_dist = length(world - cam_pos);
}

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	vec2 uv = UV * tiling + uv_offset;
	// 横向/纵向不同频率扰动，随时间缓慢流动
	vec2 perturb = vec2(
		vnoise(uv * perturb_freq + vec2(TIME * 0.02, 0.0)) - 0.5,
		vnoise(uv * perturb_freq + vec2(0.0, TIME * 0.015)) - 0.5
	);
	uv += perturb * perturb_amount;

	vec4 col = texture(base_texture, uv);

	// 指数距离雾（距离来自 vertex 插值）
	float fog = 1.0 - exp(-fog_density * max(v_dist - fog_start, 0.0));
	// 远缘渐隐：保证平面末端 100% 融进天球色（否则边缘线露馅）
	float far_fade = smoothstep(edge_fade_start, edge_fade_end, VERTEX.z);
	fog = max(fog, far_fade);
	// 远缘带从暗雾渐变为天球色 → 与天空无缝衔接
	vec3 haze = mix(fog_color, edge_fade_color, far_fade);
	vec3 final = mix(col.rgb, haze, clamp(fog, 0.0, 1.0));
	ALBEDO = final * modulate.rgb;
}
