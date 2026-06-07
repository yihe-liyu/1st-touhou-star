shader_type canvas_item;
uniform sampler2D tex;
uniform vec4 region;

void fragment() {
	vec2 uv = region.xy + UV * region.zw;
	vec4 color = texture(tex, uv);
	// MODULATE = 实例颜色（通过 mm.set_instance_color 设置）
	COLOR = color * MODULATE;
}
