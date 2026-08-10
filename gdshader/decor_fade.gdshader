shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;

// 装饰物（树）shader：远处按距离融进雾色/天球色 → 树海尽头不再是硬剪影墙
// fog_disabled：环境黑雾会抢走远处颜色，树雾由本 shader 全权控制

uniform sampler2D albedo_tex : source_color;
uniform float alpha_threshold : hint_range(0.0, 1.0) = 0.5;
uniform vec3 fog_color : source_color = vec3(0.20, 0.21, 0.24);       // 中距雾色（与地面一致）
uniform vec3 edge_fade_color : source_color = vec3(0.42, 0.44, 0.47);  // 远处亮天球雾（与地面远缘一致）
uniform float fog_density : hint_range(0.0, 0.1) = 0.018;
uniform float fog_start : hint_range(0.0, 200.0) = 55.0;
uniform float fog_full : hint_range(0.0, 400.0) = 230.0;  // 距离到达此值时完全融进天球色
uniform vec3 cam_pos = vec3(0.0, 10.0, 6.0);

varying float v_dist;

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_dist = length(world - cam_pos);
}

void fragment() {
	vec4 c = texture(albedo_tex, UV);
	if (c.a < alpha_threshold) {
		discard;
	}
	// 远处融进亮天球雾：颜色逐渐变成背景色 → 视觉上"退进雾里"，无硬墙、无生成 pop-in
	float fog = 1.0 - exp(-fog_density * max(v_dist - fog_start, 0.0));
	float t = smoothstep(fog_start, fog_full, v_dist);
	vec3 haze = mix(fog_color, edge_fade_color, t);
	ALBEDO = mix(c.rgb, haze, clamp(fog, 0.0, 1.0));
}
