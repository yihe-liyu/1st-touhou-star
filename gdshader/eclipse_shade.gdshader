shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled, blend_mix;

// 不规则黑雾层：采样值噪声云斑纹理（有机边缘）+ 圆形羽化遮罩 + TIME 流动
// 盖住规则圆太阳——弥漫的暗雾，边缘漏出太阳的规则圆弧

uniform sampler2D cloud_tex;       // 值噪声云斑纹理
uniform float cover_radius : hint_range(0.0, 1.0) = 0.42;  // 雾团覆盖半径（羽化遮罩）
uniform float density : hint_range(0.0, 2.0) = 1.2;        // 雾浓度
uniform float flow_speed : hint_range(0.0, 0.5) = 0.04;    // 流动速度
uniform vec2 shade_offset = vec2(0.0);                     // 整体错位（可动画）

void fragment() {
	vec2 p = UV - vec2(0.5, 0.5) - shade_offset;
	float d = length(p);
	// 圆形羽化遮罩：中心浓、边缘弥漫淡化（漏出太阳圆弧）
	float mask = 1.0 - smoothstep(cover_radius - 0.22, cover_radius, d);
	// 流动：UV 缓慢漂移（有机云斑缓缓流过）
	vec2 q = UV * 1.35 + vec2(TIME * flow_speed, TIME * flow_speed * 0.6);
	vec4 cloud = texture(cloud_tex, q);
	// 浓度：云斑 × 羽化遮罩，幂次加深中心
	float alpha = pow(cloud.r * mask, 1.4) * density;
	alpha = clamp(alpha, 0.0, 1.0);
	ALBEDO = vec3(0.02, 0.018, 0.015);  // 近黑暖（遮太阳的雾）
	ALPHA = alpha;
}
