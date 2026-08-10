shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled, blend_mix;

// 伪日食太阳：SphereMesh 球体——轮廓天然正圆（任何视角），无需 billboard
// fog_disabled：剧情"太阳的亮度根本没有减少"——雾不吞太阳
// fragment 用球面 UV 中心距离画黑圆（小角度近似平面圆）

uniform vec3 glow_color : source_color = vec3(1.0, 0.92, 0.72);   // 漏光暖白（阳光色）
uniform vec3 body_color : source_color = vec3(0.07, 0.05, 0.035);  // 被遮住的太阳本体（暗暖）
uniform float sun_radius : hint_range(0.0, 1.0) = 0.24;            // 黑圆半径（球面 UV）
uniform float edge_rough : hint_range(0.0, 0.1) = 0.006;           // 黑圆边缘不规则度
uniform float glow_width : hint_range(0.0, 1.0) = 0.12;            // 边缘漏光带宽
uniform float halo_size : hint_range(0.0, 2.0) = 0.9;              // 日冕光晕范围
uniform float hdr_gain : hint_range(1.0, 8.0) = 3.0;               // HDR 亮度
uniform vec2 sun_offset = vec2(0.0);                               // 黑圆错位（日食偏移动画）
uniform float ring_density : hint_range(1.0, 60.0) = 14.0;         // 漏光衰减速度

void fragment() {
	vec2 p = UV - vec2(0.5, 0.5) - sun_offset;
	float d = length(p);
	// 球面弧长修正（小角度近似）：d_arc = 2*asin(d) ≈ d
	// 不规则黑圆边缘（低频 sin → 微凹凸）
	float r = sun_radius * (1.0 + edge_rough * sin(p.x * 24.0 + p.y * 19.0));
	// 圆内 body=1（smoothstep 升序）
	float body = 1.0 - smoothstep(r - 0.02, r, d);
	// ① 日冕光晕：大范围柔和扩散
	float halo = exp(-d * (3.0 / max(halo_size, 0.01)));
	// ② 边缘漏光：黑圆边缘溢出明亮阳光
	float ring = exp(-(d - r) * ring_density) * step(d, r + glow_width);
	vec3 col = glow_color * (ring * hdr_gain + halo * hdr_gain * 0.35);
	// ③ 黑圆本体：暗暖太阳表面（微明暗）
	vec3 body_col = body_color * (1.05 + 0.08 * sin(p.x * 40.0 + d * 12.0));
	ALBEDO = mix(body_col, col, 1.0 - body);
	EMISSION = col * (1.0 - body) * 2.0;
	ALPHA = clamp(max(body, ring + halo * 0.5), 0.0, 1.0);
}
