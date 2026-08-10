shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled, blend_mix;

// 伪日食太阳：不规则的黑色圆遮住太阳，边缘漏出较亮的光芒
// 此 fork 阉割了 GeometryInstance3D.billboard_mode → 手动 shader billboard
void vertex() {
	vec4 wpos = MODEL_MATRIX * vec4(VERTEX, 1.0);
	vec4 vpos = VIEW_MATRIX * wpos;
	POSITION = PROJECTION_MATRIX * vec4(VERTEX.xy, vpos.z, 1.0);
}

uniform vec3 glow_color : source_color = vec3(1.0, 0.92, 0.72);   // 漏光暖白（阳光色）
uniform vec3 body_color : source_color = vec3(0.07, 0.05, 0.035);  // 被遮住的太阳本体（暗暖）
uniform float sun_radius : hint_range(0.0, 1.0) = 0.24;            // 黑圆半径（相对 quad）
uniform float edge_rough : hint_range(0.0, 0.1) = 0.008;           // 黑圆边缘不规则度（低频低幅→圆）
uniform float glow_width : hint_range(0.0, 1.0) = 0.10;            // 边缘漏光带宽
uniform float halo_size : hint_range(0.0, 2.0) = 0.9;              // 日冕光晕范围
uniform float hdr_gain : hint_range(1.0, 8.0) = 4.0;               // HDR 亮度（吃 Environment glow）
uniform vec2 sun_offset = vec2(0.0);                               // 黑圆错位（日食偏移动画）
uniform float ring_density : hint_range(1.0, 60.0) = 18.0;         // 漏光衰减速度

void fragment() {
	vec2 p = UV - 0.5 - sun_offset;
	float d = length(p);
	// 不规则黑圆边缘（低频 sin → 微凹凸，仍是圆形）
	float r = sun_radius * (1.0 + edge_rough * sin(p.x * 24.0 + p.y * 19.0));
	// 圆内 body=1：注意 smoothstep 参数必须升序（edge0 < edge1）
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
	// 圆内不透明（显示暗暖本体），圆外按光强渐隐
	ALPHA = clamp(max(body, ring + halo * 0.5), 0.0, 1.0);
}
