shader_type canvas_item;
uniform sampler2D tex;
uniform vec4 region;

void fragment() {
	vec2 uv = region.xy + UV * region.zw;
	COLOR = texture(tex, uv) * COLOR;
}
