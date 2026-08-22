shader_type canvas_item;
uniform vec4 fog_tint = vec4(1.0);

void fragment() {
	vec4 col = texture(TEXTURE, UV);
	float gray = dot(col.rgb, vec3(0.299, 0.587, 0.114));
	// 淡出用 modulate.a（普通属性，无每帧材质上传），故乘上 COLOR.a
	COLOR = vec4(mix(fog_tint.rgb, vec3(1.0), gray), col.a * fog_tint.a * COLOR.a);
}
