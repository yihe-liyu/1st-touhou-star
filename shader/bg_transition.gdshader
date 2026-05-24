shader_type canvas_item;
render_mode blend_mix;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform int type : hint_range(0, 3) = 0;
uniform vec4 edge_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float edge_width : hint_range(0.0, 0.3) = 0.05;

float radial_mask(vec2 uv) {
	float dist = length(uv - 0.5) * 2.0;
	return smoothstep(progress - edge_width, progress + edge_width, dist);
}

float wipe_left_mask(vec2 uv) {
	return smoothstep(progress - edge_width, progress + edge_width, uv.x);
}

float diamond_mask(vec2 uv) {
	vec2 q = abs(uv - 0.5);
	float d = q.x + q.y;
	return smoothstep(progress - edge_width, progress + edge_width, d);
}

float noise_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise_mask(vec2 uv) {
	float n = noise_hash(uv * 80.0 + progress * 10.0);
	return smoothstep(progress - 0.1, progress + 0.1, n);
}

void fragment() {
	vec4 col = texture(SCREEN_TEXTURE, SCREEN_UV);

	float mask;
	if (type == 0) {
		mask = radial_mask(SCREEN_UV);
	} else if (type == 1) {
		mask = wipe_left_mask(SCREEN_UV);
	} else if (type == 2) {
		mask = diamond_mask(SCREEN_UV);
	} else {
		mask = noise_mask(SCREEN_UV);
	}

	col.rgb = mix(edge_color.rgb, col.rgb, mask);
	col.a = mix(edge_color.a, col.a, mask);

	COLOR = col;
}
