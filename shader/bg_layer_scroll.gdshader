shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled;

uniform sampler2D layer_texture : source_color, filter_linear_mipmap;
uniform vec2 scroll_speed = vec2(0.0, -0.1);
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform int blend_mode : hint_range(0, 2) = 0;
uniform float blend_strength : hint_range(0.0, 1.0) = 0.0;
uniform float u_custom_time = 0.0;

void vertex() {
}

void fragment() {
	vec2 scrolled_uv = UV + scroll_speed * u_custom_time;
	vec4 tex = texture(layer_texture, scrolled_uv);

	if (blend_mode == 1) {
		ALBEDO = mix(tex.rgb, tex.rgb + tint.rgb, blend_strength);
		ALPHA = tex.a * tint.a;
	} else if (blend_mode == 2) {
		ALBEDO = mix(tex.rgb, tex.rgb * tint.rgb, blend_strength);
		ALPHA = tex.a * tint.a;
	} else {
		ALBEDO = tex.rgb * tint.rgb;
		ALPHA = tex.a * tint.a;
	}
}
