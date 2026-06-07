shader_type canvas_item;
uniform sampler2D tex;
uniform vec4 region;
uniform int tint_mode = 0;

void fragment() {
	vec2 uv = region.xy + UV * region.zw;
	vec4 col = texture(tex, uv);
	
	if (tint_mode == 0) {
		// 乘法叠加：原来的方式，适合带颜色纹理
		COLOR = col * COLOR;
	} else {
		// 灰度混合：白色保持不变，只染暗部（贴图需为白色/灰色底图）
		float gray = dot(col.rgb, vec3(0.299, 0.587, 0.114));
		COLOR = vec4(mix(COLOR.rgb, vec3(1.0), gray), col.a * COLOR.a);
	}
}
