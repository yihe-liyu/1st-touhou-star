shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled, blend_mix;

// 不规则黑雾层：盖住规则圆太阳——"不那么规则的黑色圆"
// 边缘 = 多层正弦噪声叠加（TIME 驱动 → 缓慢飘动变形）
// 不采样纹理（纯形状计算）——alpha 渐隐边缘

uniform float shade_radius : hint_range(0.0, 1.0) = 0.36;   // 黑雾覆盖半径
uniform float edge_soft : hint_range(0.0, 0.1) = 0.025;     // 边缘柔和度
uniform float drift_speed : hint_range(0.0, 1.0) = 0.25;    // 飘动速度
uniform vec2 shade_offset = vec2(0.0);                      // 整体错位（可动画）

void fragment() {
	vec2 p = UV - vec2(0.5, 0.5) - shade_offset;
	float d = length(p);
	// 不规则半径：三层噪声叠加（角度方向 + 时间 → 边缘凹凸且缓慢变化）
	float r = shade_radius;
	r += 0.035 * sin(p.x * 7.0 + p.y * 3.0 + TIME * drift_speed);
	r += 0.022 * sin(p.y * 9.0 - p.x * 5.0 + TIME * drift_speed * 0.7 + 1.7);
	r += 0.016 * sin(dot(p, vec2(13.0, 7.0)) + TIME * drift_speed * 0.5 + 4.2);
	// 黑雾本体（边缘柔和过渡）
	float body = 1.0 - smoothstep(r - edge_soft, r, d);
	ALBEDO = vec3(0.015, 0.012, 0.01);  // 近黑（带一点暖——遮住太阳的黑雾）
	ALPHA = body;
}
