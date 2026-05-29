shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
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
	
	#define CHECK_CIRCLE(i, pos, rad, alp) \
		if (pos.x >= -0.5) { \
			float d = distance(UV, pos); \
			float ci = 1.0 - smoothstep(rad - edge_soft, rad + edge_soft, d); \
			mask = max(mask, ci * alp); \
		}
	
	CHECK_CIRCLE(0, c0_pos, c0_radius, c0_alpha)
	CHECK_CIRCLE(1, c1_pos, c1_radius, c1_alpha)
	CHECK_CIRCLE(2, c2_pos, c2_radius, c2_alpha)
	CHECK_CIRCLE(3, c3_pos, c3_radius, c3_alpha)
	CHECK_CIRCLE(4, c4_pos, c4_radius, c4_alpha)
	CHECK_CIRCLE(5, c5_pos, c5_radius, c5_alpha)
	CHECK_CIRCLE(6, c6_pos, c6_radius, c6_alpha)
	CHECK_CIRCLE(7, c7_pos, c7_radius, c7_alpha)
	
	vec4 inverted = vec4(1.0 - bg.rgb, 1.0);
	COLOR = mix(bg, inverted, mask);
}
