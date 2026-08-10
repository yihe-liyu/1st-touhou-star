shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled, billboard, blend_mix;

// 伪日食太阳：不规则的黑色圆遮住太阳，边缘漏出较亮的光芒
// 独立 quad 元素（billboard），黑圆可偏移/缩放做日食错位动画

uniform vec3 glow_color : source_color = vec3(1.0, 0.82, 0.5);  // 漏光暖金色
uniform float sun_radius : hint_range(0.0, 1.0) = 0.30;          // 黑圆半径（相对 quad）
uniform float edge_rough : hint_range(0.0, 0.1) = 0.015;         // 黑圆边缘不规则度
uniform float glow_width : hint_range(0.0, 1.0) = 0.12;          // 亮环宽（漏光带）
uniform float hdr_gain : hint_range(1.0, 8.0) = 3.0;             // HDR 亮度（吃 Environment glow）
uniform vec2 sun_offset = vec2(0.0);                             // 黑圆错位（伪日食偏移动画）
uniform float ring_density : hint_range(1.0, 60.0) = 20.0;       // 亮环衰减速度

void fragment() {
	vec2 p = UV - 0.5 - sun_offset;
	float d = length(p);
	// 不规则黑圆边缘：正弦噪声扰动半径（"不那么规则的黑色圆"）
	float r = sun_radius * (1.0 + edge_rough * sin(p.x * 60.0 + p.y * 47.0));
	// 黑圆本体：圆内为 1（盖住太阳）
	float body = smoothstep(r, r - 0.01, d);
	// 亮环：边缘指数衰减的暖光（太阳被盖住，仅周边露出较亮的光芒）
	float ring = exp(-(d - r) * ring_density) * step(d, r + glow_width);
	vec3 col = glow_color * ring * hdr_gain;
	ALBEDO = mix(vec3(0.0), col, 1.0 - body);
	EMISSION = col * (1.0 - body);
	ALPHA = 1.0 - body + ring;
}
