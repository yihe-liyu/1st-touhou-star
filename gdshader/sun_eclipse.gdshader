shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled, blend_mix;

// 伪日食太阳：不规则的黑色圆遮住太阳，边缘漏出较亮的光芒
// 黑圆不是"黑洞"——是暗暖的太阳本体被遮住；外圈有日冕光晕
// 此 fork 阉割了 GeometryInstance3D.billboard_mode → 手动 shader billboard
void vertex() {
	vec4 wpos = MODEL_MATRIX * vec4(VERTEX, 1.0);
	vec4 vpos = VIEW_MATRIX * wpos;
	POSITION = PROJECTION_MATRIX * vec4(VERTEX.xy, vpos.z, 1.0);
}

uniform vec3 glow_color : source_color = vec3(1.0, 0.92, 0.72);  // 漏光暖白（阳光色）
uniform vec3 body_color : source_color = vec3(0.07, 0.05, 0.035); // 被遮住的太阳本体（暗暖，非纯黑）
uniform float sun_radius : hint_range(0.0, 1.0) = 0.24;           // 黑圆半径（相对 quad）
uniform float edge_rough : hint_range(0.0, 0.1) = 0.02;           // 黑圆边缘不规则度
uniform float glow_width : hint_range(0.0, 1.0) = 0.10;           // 边缘漏光带宽
uniform float halo_size : hint_range(0.0, 2.0) = 0.9;             // 日冕光晕范围
uniform float hdr_gain : hint_range(1.0, 8.0) = 4.0;              // HDR 亮度（吃 Environment glow）
uniform vec2 sun_offset = vec2(0.0);                              // 黑圆错位（日食偏移动画）
uniform float ring_density : hint_range(1.0, 60.0) = 18.0;        // 漏光衰减速度

void fragment() {
	vec2 p = UV - 0.5 - sun_offset;
	float d = length(p);
	// 不规则黑圆边缘（"不那么规则的黑色圆"）
	float r = sun_radius * (1.0 + edge_rough * sin(p.x * 60.0 + p.y * 47.0));
	float body = smoothstep(r, r - 0.01, d);
	// ① 日冕光晕：大范围柔和扩散（太阳被压暗但光仍在）
	float halo = exp(-d * (3.0 / max(halo_size, 0.01)));
	// ② 边缘漏光：黑圆边缘溢出明亮的阳光
	float ring = exp(-(d - r) * ring_density) * step(d, r + glow_width);
	vec3 col = glow_color * (ring * hdr_gain + halo * hdr_gain * 0.35);
	// ③ 黑圆本体：暗暖的太阳表面（微不规则明暗，非纯黑）
	vec3 body_col = body_color * (1.05 + 0.08 * sin(p.x * 40.0 + d * 12.0));
	vec3 albedo = mix(body_col, col, 1.0 - body);
	ALBEDO = albedo;
	EMISSION = col * (1.0 - body) * 2.0;
	ALPHA = clamp(max(body, col.r + col.g + col.b), 0.0, 1.0);
}
