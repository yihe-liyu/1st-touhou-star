shader_type canvas_item;
render_mode blend_mix;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.0;
uniform vec4 vignette_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float chromatic_strength : hint_range(0.0, 0.05) = 0.0;
uniform float scanline_strength : hint_range(0.0, 1.0) = 0.0;
uniform vec4 scanline_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 overlay_color : source_color = vec4(0.0, 0.0, 0.0, 0.0);

void fragment() {
	vec3 col = texture(SCREEN_TEXTURE, SCREEN_UV).rgb;

	float r = texture(SCREEN_TEXTURE, SCREEN_UV + vec2(chromatic_strength, 0.0)).r;
	float b = texture(SCREEN_TEXTURE, SCREEN_UV - vec2(chromatic_strength, 0.0)).b;
	col = vec3(r, col.g, b);

	if (scanline_strength > 0.0) {
		float line = sin(SCREEN_UV.y * SCREEN_PIXEL_SIZE.y * 400.0) * 0.5 + 0.5;
		col = mix(col, scanline_color.rgb, line * scanline_strength * scanline_color.a);
	}

	if (vignette_strength > 0.0) {
		vec2 uv_center = SCREEN_UV - 0.5;
		float dist = length(uv_center) * 1.5;
		float vignette = smoothstep(0.2, 1.0, dist) * vignette_strength;
		col = mix(col, vignette_color.rgb, vignette * vignette_color.a);
	}

	col = mix(col, overlay_color.rgb, overlay_color.a);

	COLOR = vec4(col, 1.0);
}
