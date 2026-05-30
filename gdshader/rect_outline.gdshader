shader_type canvas_item;

uniform vec4 border_color : source_color = vec4(0.5, 0.5, 0.5, 1.0);
uniform float border_width : hint_range(1.0, 20.0) = 3.0;

void fragment() {
	vec2 ps = 1.0 / TEXTURE_PIXEL_SIZE;  // rect 的宽高像素数
	
	float dist_left   = UV.x * ps.x;
	float dist_right  = (1.0 - UV.x) * ps.x;
	float dist_top    = UV.y * ps.y;
	float dist_bottom = (1.0 - UV.y) * ps.y;
	
	float min_dist = min(min(dist_left, dist_right), min(dist_top, dist_bottom));
	
	float alpha = step(min_dist, border_width);
	COLOR = vec4(border_color.rgb, alpha * border_color.a);
}
