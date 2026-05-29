shader_type canvas_item;

// 测试 screen_tex —— 直通，屏幕应该正常（不反色）
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;

void fragment() {
	COLOR = texture(screen_tex, SCREEN_UV);
}
