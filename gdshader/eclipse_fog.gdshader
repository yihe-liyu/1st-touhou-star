shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled, blend_mix;
// 伪日食黑雾（云片）——FastNoiseLite 云纹理做 alpha（真云絮状）
// 中心区云加浓（盖住太阳），外缘絮状淡出；透明度不均匀（云丝）

uniform sampler2D cloud;
uniform float density : hint_range(0.0, 1.5) = 0.95;

void fragment() {
	float d = distance(UV, vec2(0.5, 0.5));
	float cloud_v = texture(cloud, UV * 1.4).r;      // 云噪声（分形）
	// 中心浓（盖太阳）、外缘淡
	float core = 1.0 - smoothstep(0.10, 0.50, d);
	// 云形状：噪声值决定浓淡（云的絮状不均匀）
	float alpha = cloud_v * (0.25 + core * 0.75) * density;
	ALBEDO = vec3(0.015, 0.013, 0.012);
	ALPHA = clamp(alpha, 0.0, 1.0);
}
