shader_type canvas_item;

uniform vec4 rect_color : source_color = vec4(0.5, 0.5, 0.5, 1.0);
uniform float line_width : hint_range(0.0, 10.0) = 2.0;
uniform vec2 rect_uv_min = vec2(0.05, 0.05);
uniform vec2 rect_uv_max = vec2(0.95, 0.95);

void fragment() {
	float left   = step(rect_uv_min.x, UV.x);
	float right  = step(UV.x, rect_uv_max.x);
	float bottom = step(rect_uv_min.y, UV.y);
	float top    = step(UV.y, rect_uv_max.y);
	float inside = left * right * bottom * top;
	
	float inner_left   = step(rect_uv_min.x + line_width * TEXTURE_PIXEL_SIZE.x, UV.x);
	float inner_right  = step(UV.x, rect_uv_max.x - line_width * TEXTURE_PIXEL_SIZE.x);
	float inner_bottom = step(rect_uv_min.y + line_width * TEXTURE_PIXEL_SIZE.y, UV.y);
	float inner_top    = step(UV.y, rect_uv_max.y - line_width * TEXTURE_PIXEL_SIZE.y);
	float inner = inner_left * inner_right * inner_bottom * inner_top;
	
	float line = inside * (1.0 - inner);
	COLOR = vec4(rect_color.rgb, line * rect_color.a);
}
