shader_type canvas_item;

/// 灰度强度: 0.0 = 彩色, 1.0 = 完全黑白
uniform float grayscale : hint_range(0.0, 1.0) = 0.0;
/// 亮度倍率: 1.0 = 原亮, 0.0 = 全黑
uniform float brightness : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float gray = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	vec3 col = mix(tex.rgb, vec3(gray), grayscale);
	COLOR = vec4(col * brightness, tex.a);
}
