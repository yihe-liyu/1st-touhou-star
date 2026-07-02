shader_type canvas_item;
uniform vec4 fog_tint = vec4(1.0);

void fragment() {
	vec4 col = texture(TEXTURE, UV);
	float gray = dot(col.rgb, vec3(0.299, 0.587, 0.114));
	COLOR = vec4(mix(fog_tint.rgb, vec3(1.0), gray), col.a * fog_tint.a);
}
