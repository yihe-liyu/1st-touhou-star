shader_type canvas_item;

void fragment() {
	vec4 col = texture(TEXTURE, UV);
	// COLOR 初始值 = Sprite2D.modulate（vertex-interpolated）
	vec4 tint = COLOR;
	float gray = dot(col.rgb, vec3(0.299, 0.587, 0.114));
	COLOR = vec4(mix(tint.rgb, vec3(1.0), gray), col.a * tint.a);
}
