shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float circle_radius = 0.3;
uniform float alpha = 0.8;
uniform float edge_soft = 0.03;

void fragment() {
	vec2 center = vec2(0.5, 0.5);
	float dist = distance(UV, center);
	float mask = 1.0 - smoothstep(circle_radius - edge_soft, circle_radius + edge_soft, dist);
	
	vec4 bg = texture(screen_tex, SCREEN_UV);
	vec4 inverted = vec4(1.0 - bg.rgb, 1.0);
	COLOR = mix(bg, inverted, mask * alpha);
}
