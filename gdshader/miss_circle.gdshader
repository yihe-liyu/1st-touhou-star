shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform vec2 vs = vec2(1280.0, 960.0);  // viewport size for aspect correction

uniform vec2 c0_pos = vec2(-1.0);
uniform float c0_radpx = 0.0;  // radius in pixels
uniform float c0_alpha = 0.0;
uniform vec2 c1_pos = vec2(-1.0);
uniform float c1_radpx = 0.0;
uniform float c1_alpha = 0.0;
uniform vec2 c2_pos = vec2(-1.0);
uniform float c2_radpx = 0.0;
uniform float c2_alpha = 0.0;
uniform vec2 c3_pos = vec2(-1.0);
uniform float c3_radpx = 0.0;
uniform float c3_alpha = 0.0;
uniform vec2 c4_pos = vec2(-1.0);
uniform float c4_radpx = 0.0;
uniform float c4_alpha = 0.0;
uniform vec2 c5_pos = vec2(-1.0);
uniform float c5_radpx = 0.0;
uniform float c5_alpha = 0.0;
uniform vec2 c6_pos = vec2(-1.0);
uniform float c6_radpx = 0.0;
uniform float c6_alpha = 0.0;
uniform vec2 c7_pos = vec2(-1.0);
uniform float c7_radpx = 0.0;
uniform float c7_alpha = 0.0;

uniform float edge_soft = 0.03;

// 用像素级归一化保证正圆: (dx_px)^2 + (dy_px)^2 <= radius^2
#define CHECK_PX(i, pos, radpx, alp) \
	if (pos.x >= -0.5) { \
		float dx = (UV.x - pos.x) * vs.x; \
		float dy = (UV.y - pos.y) * vs.y; \
		float dist = sqrt(dx * dx + dy * dy); \
		float ci = 1.0 - smoothstep(radpx - edge_soft * radpx, radpx + edge_soft * radpx, dist); \
		mask = clamp(mask + ci * alp, 0.0, 1.0); \
	}

void fragment() {
	vec4 bg = texture(screen_tex, SCREEN_UV);
	float mask = 0.0;
	
	CHECK_PX(0, c0_pos, c0_radpx, c0_alpha)
	CHECK_PX(1, c1_pos, c1_radpx, c1_alpha)
	CHECK_PX(2, c2_pos, c2_radpx, c2_alpha)
	CHECK_PX(3, c3_pos, c3_radpx, c3_alpha)
	CHECK_PX(4, c4_pos, c4_radpx, c4_alpha)
	CHECK_PX(5, c5_pos, c5_radpx, c5_alpha)
	CHECK_PX(6, c6_pos, c6_radpx, c6_alpha)
	CHECK_PX(7, c7_pos, c7_radpx, c7_alpha)
	
	vec4 inverted = vec4(1.0 - bg.rgb, 1.0);
	COLOR = mix(bg, inverted, mask);
}
