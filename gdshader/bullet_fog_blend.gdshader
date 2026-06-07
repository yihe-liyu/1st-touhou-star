shader_type canvas_item;
// BulletFog BLEND 模式 — 白色保持不变，只染暗部

void fragment() {
	vec4 col = texture(TEXTURE, UV);
	float gray = dot(col.rgb, vec3(0.299, 0.587, 0.114));
	// MODULATE = Sprite2D.modulate（由脚本传入的 tint）
	COLOR = vec4(mix(MODULATE.rgb, vec3(1.0), gray), col.a * MODULATE.a);
}
