shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float aspect_ratio = 1.0;  // vs.x / vs.y

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
	
	// 修正宽高比，让圆不扁
	vec2 uv_corrected = UV * vec2(1.0, aspect_ratio);
	
	#define CHECK(i, pos, rad, alp) \
		if (pos.x >= -0.5) { \
			vec2 pc = pos * vec2(1.0, aspect_ratio); \
			float d = distance(uv_corrected, pc); \
			float ci = 1.0 - smoothstep(rad - edge_soft, rad + edge_soft, d); \
			/* 叠加：mask 累加，clamp 到 0~1 */ \
			mask = clamp(mask + ci * alp, 0.0, 1.0); \
		}
	
	CHECK(0, c0_pos, c0_radius, c0_alpha)
	CHECK(1, c1_pos, c1_radius, c1_alpha)
	CHECK(2, c2_pos, c2_radius, c2_alpha)
	CHECK(3, c3_pos, c3_radius, c3_alpha)
	CHECK(4, c4_pos, c4_radius, c4_alpha)
	CHECK(5, c5_pos, c5_radius, c5_alpha)
	CHECK(6, c6_pos, c6_radius, c6_alpha)
	CHECK(7, c7_pos, c7_radius, c7_alpha)
	
	vec4 inverted = vec4(1.0 - bg.rgb, 1.0);
	COLOR = mix(bg, inverted, mask);
}
