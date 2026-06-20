shader_type canvas_item;

uniform float alpha_mult : hint_range(0, 1) = 1.0;
uniform vec4 border_color : source_color = vec4(0.5, 0.5, 0.5, 1.0);
uniform float border_width : hint_range(1.0, 20.0) = 3.0;
uniform vec2 rect_size = vec2(384.0, 256.0);  // rect 的像素尺寸，需从脚本设置

void fragment() {
	float dist_left   = UV.x * rect_size.x;
	float dist_right  = (1.0 - UV.x) * rect_size.x;
	float dist_top    = UV.y * rect_size.y;
	float dist_bottom = (1.0 - UV.y) * rect_size.y;
	
	float min_dist = min(min(dist_left, dist_right), min(dist_top, dist_bottom));
	
	float alpha = step(min_dist, border_width);
	COLOR = vec4(border_color.rgb, alpha * border_color.a * alpha_mult);
}
