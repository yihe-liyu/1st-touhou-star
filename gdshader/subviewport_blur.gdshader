shader_type canvas_item;

uniform float blur_strength : hint_range(0, 8) = 3.0;
uniform float darken : hint_range(0, 1) = 0.45;

void fragment() {
	// 先测试：全红，看 material 有没有生效
	COLOR = vec4(1.0, 0.0, 0.0, 0.5);
	return;
	
	vec2 ps = TEXTURE_PIXEL_SIZE * blur_strength;
	vec4 color = vec4(0.0);
	
	for (int x = -2; x <= 2; x++) {
		for (int y = -2; y <= 2; y++) {
			vec2 offset = vec2(float(x), float(y)) * ps;
			color += texture(TEXTURE, UV + offset);
		}
	}
	color /= 25.0;
	
	COLOR = vec4(color.rgb * (1.0 - darken), 1.0);
}
