shader_type canvas_item;

// 全局 miss 反色特效 —— 同时支持多个扩散圆
// 只用一个全屏 ColorRect，不会互相抵消

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;

const int MAX_CIRCLES = 8;

uniform vec2 c_pos[MAX_CIRCLES];
uniform float c_radius[MAX_CIRCLES]; // 0..1，占 UV 半高的比值
uniform float c_alpha[MAX_CIRCLES];
uniform float edge_soft = 0.03;

void fragment() {
	vec4 bg = texture(screen_tex, SCREEN_UV);
	
	float mask = 0.0;
	for (int i = 0; i < MAX_CIRCLES; i++) {
		float dist = distance(UV, c_pos[i]);
		float ci = 1.0 - smoothstep(c_radius[i] - edge_soft, c_radius[i] + edge_soft, dist);
		mask = max(mask, ci * c_alpha[i]);
	}
	
	vec4 inverted = vec4(1.0 - bg.rgb, 1.0);
	COLOR = mix(bg, inverted, mask);
}
