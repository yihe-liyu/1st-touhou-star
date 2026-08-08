shader_type canvas_item;
// 伪日食黑雾（2D 屏幕空间——覆在摄像机/太阳投影上，零几何问题）
// FastNoiseLite 云纹理做 alpha（真云絮状）；中心浓盖太阳、外缘絮状淡出

uniform sampler2D cloud;
uniform float density : hint_range(0.0, 1.5) = 0.95;

void fragment() {
	float d = distance(UV, vec2(0.5, 0.5));
	float cloud_v = texture(cloud, UV * 1.6).r;      // 云噪声（分形）
	float core = 1.0 - smoothstep(0.12, 0.55, d);    // 中心浓（盖太阳）外缘淡
	float alpha = cloud_v * (0.25 + core * 0.75) * density;
	COLOR = vec4(vec3(0.015, 0.013, 0.012), clamp(alpha, 0.0, 1.0));
}
