shader_type canvas_item;

uniform float blur_strength : hint_range(0, 8) = 3.0;
uniform float darken : hint_range(0, 1) = 0.55;

void fragment() {
	// SCREEN_TEXTURE = 屏幕当前画面
	// SCREEN_UV = 屏幕坐标
	// SCREEN_PIXEL_SIZE = 每像素大小
	
	vec2 ps = SCREEN_PIXEL_SIZE * blur_strength;
	vec4 color = vec4(0.0);
	
	// 5×5 box blur — 采样周围 25 个像素求平均
	for (int x = -2; x <= 2; x++) {
		for (int y = -2; y <= 2; y++) {
			vec2 offset = vec2(float(x), float(y)) * ps;
			color += texture(SCREEN_TEXTURE, SCREEN_UV + offset);
		}
	}
	color /= 25.0;
	
	// 变暗 → 毛玻璃效果
	COLOR = vec4(color.rgb * (1.0 - darken), 1.0);
}
