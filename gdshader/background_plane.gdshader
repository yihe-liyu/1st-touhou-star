shader_type spatial;
render_mode unshaded;

uniform sampler2D base_texture : source_color;
uniform vec2 tiling = vec2(6.0);
uniform vec2 uv_offset = vec2(0.0);
uniform vec4 modulate : source_color = vec4(1.0);

// ── 距离雾：近清远朦，远处融进日食暗雾（打破"贴纸地面"感）──
uniform vec3 fog_color : source_color = vec3(0.12, 0.13, 0.15);
uniform float fog_density : hint_range(0.0, 0.1) = 0.012;
uniform float fog_start : hint_range(0.0, 200.0) = 55.0;

// ── 平铺扰动：双档噪声随时间缓慢流动，减轻重复感 ──
uniform float perturb_amount : hint_range(0.0, 0.2) = 0.035;
uniform float perturb_freq : hint_range(0.0, 4.0) = 0.9;

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

	// 指数距离雾：VIEW = 视空间坐标
	float dist = length(VIEW);
	float fog = 1.0 - exp(-fog_density * max(dist - fog_start, 0.0));
	vec3 final = mix(col.rgb, fog_color, clamp(fog, 0.0, 1.0));
	ALBEDO = final * modulate.rgb;
}
