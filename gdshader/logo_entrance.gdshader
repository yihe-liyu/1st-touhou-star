shader_type canvas_item;

uniform float progress : hint_range(0, 1) = 0.0;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);

	// 从中心向外的圆形展开
	vec2 center = vec2(0.5, 0.5);
	float dist = distance(UV, center);
	float max_dist = distance(vec2(0.5, 0.5), vec2(1.0, 1.0));

	float radius = max_dist * progress;
	float reveal = 1.0 - smoothstep(radius - 0.04, radius + 0.04, dist);

	// 展开边缘的辉光
	float glow = exp(-abs(dist - radius) * 25.0) * 0.5;

	vec3 logo_color = tex.rgb * reveal;
	vec3 glow_color = vec3(glow * 0.6, glow * 0.8, glow);
	// 辉光让 logo 边缘更亮
	COLOR = vec4(logo_color + glow_color, tex.a * (reveal + glow * 0.3));
}
