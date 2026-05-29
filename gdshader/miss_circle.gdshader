shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float aspect_ratio = 1.0;

uniform vec2 c0_pos = vec2(-1.0);
uniform float c0_radius = 0.0;
uniform float c0_alpha = 0.0;
uniform vec2 c1_pos = vec2(-1.0);
uniform float c1_radius = 0.0;
uniform float c1_alpha = 0.0;
uniform vec2 c2_pos = vec2(-1.0);
uniform float c2_radius = 0.0;
uniform float c2_alpha = 0.0;
uniform vec2 c3_pos = vec2(-1.0);
uniform float c3_radius = 0.0;
uniform float c3_alpha = 0.0;
uniform vec2 c4_pos = vec2(-1.0);
uniform float c4_radius = 0.0;
uniform float c4_alpha = 0.0;
uniform vec2 c5_pos = vec2(-1.0);
uniform float c5_radius = 0.0;
uniform float c5_alpha = 0.0;
uniform vec2 c6_pos = vec2(-1.0);
uniform float c6_radius = 0.0;
uniform float c6_alpha = 0.0;
uniform vec2 c7_pos = vec2(-1.0);
uniform float c7_radius = 0.0;
uniform float c7_alpha = 0.0;

uniform float edge_soft = 0.03;

void fragment() {
	vec4 bg = texture(screen_tex, SCREEN_UV);
	float mask = 0.0;
	
	// 只对 Y 轴做宽高比修正
	float dx, dy, dist, ci;
	
	if (c0_pos.x >= -0.5) {
		dx = UV.x - c0_pos.x;
		dy = (UV.y - c0_pos.y) * aspect_ratio;
		dist = sqrt(dx * dx + dy * dy);
		ci = 1.0 - smoothstep(c0_radius - edge_soft, c0_radius + edge_soft, dist);
		mask = clamp(mask + ci * c0_alpha, 0.0, 1.0);
	}
	if (c1_pos.x >= -0.5) {
		dx = UV.x - c1_pos.x;
		dy = (UV.y - c1_pos.y) * aspect_ratio;
		dist = sqrt(dx * dx + dy * dy);
		ci = 1.0 - smoothstep(c1_radius - edge_soft, c1_radius + edge_soft, dist);
		mask = clamp(mask + ci * c1_alpha, 0.0, 1.0);
	}
	if (c2_pos.x >= -0.5) {
		dx = UV.x - c2_pos.x;
		dy = (UV.y - c2_pos.y) * aspect_ratio;
		dist = sqrt(dx * dx + dy * dy);
		ci = 1.0 - smoothstep(c2_radius - edge_soft, c2_radius + edge_soft, dist);
		mask = clamp(mask + ci * c2_alpha, 0.0, 1.0);
	}
	if (c3_pos.x >= -0.5) {
		dx = UV.x - c3_pos.x;
		dy = (UV.y - c3_pos.y) * aspect_ratio;
		dist = sqrt(dx * dx + dy * dy);
		ci = 1.0 - smoothstep(c3_radius - edge_soft, c3_radius + edge_soft, dist);
		mask = clamp(mask + ci * c3_alpha, 0.0, 1.0);
	}
	if (c4_pos.x >= -0.5) {
		dx = UV.x - c4_pos.x;
		dy = (UV.y - c4_pos.y) * aspect_ratio;
		dist = sqrt(dx * dx + dy * dy);
		ci = 1.0 - smoothstep(c4_radius - edge_soft, c4_radius + edge_soft, dist);
		mask = clamp(mask + ci * c4_alpha, 0.0, 1.0);
	}
	if (c5_pos.x >= -0.5) {
		dx = UV.x - c5_pos.x;
		dy = (UV.y - c5_pos.y) * aspect_ratio;
		dist = sqrt(dx * dx + dy * dy);
		ci = 1.0 - smoothstep(c5_radius - edge_soft, c5_radius + edge_soft, dist);
		mask = clamp(mask + ci * c5_alpha, 0.0, 1.0);
	}
	if (c6_pos.x >= -0.5) {
		dx = UV.x - c6_pos.x;
		dy = (UV.y - c6_pos.y) * aspect_ratio;
		dist = sqrt(dx * dx + dy * dy);
		ci = 1.0 - smoothstep(c6_radius - edge_soft, c6_radius + edge_soft, dist);
		mask = clamp(mask + ci * c6_alpha, 0.0, 1.0);
	}
	if (c7_pos.x >= -0.5) {
		dx = UV.x - c7_pos.x;
		dy = (UV.y - c7_pos.y) * aspect_ratio;
		dist = sqrt(dx * dx + dy * dy);
		ci = 1.0 - smoothstep(c7_radius - edge_soft, c7_radius + edge_soft, dist);
		mask = clamp(mask + ci * c7_alpha, 0.0, 1.0);
	}
	
	vec4 inverted = vec4(1.0 - bg.rgb, 1.0);
	COLOR = mix(bg, inverted, mask);
}
