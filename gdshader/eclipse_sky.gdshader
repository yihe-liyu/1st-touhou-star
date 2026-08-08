shader_type sky;
// 伪日食天色（sky shader 官方：void sky() + out vec3 COLOR + EYEDIR）
// 太阳/雾由 3D 球 + 云雾片负责（sky 只做暗色渐变天色背景）

uniform vec4 horizon_color : source_color = vec4(0.20, 0.21, 0.25, 1.0);
uniform vec4 top_color : source_color = vec4(0.08, 0.09, 0.12, 1.0);
uniform vec4 ground_color : source_color = vec4(0.05, 0.05, 0.07, 1.0);

void sky() {
	vec3 rd = normalize(EYEDIR);
	vec3 col;
	if (rd.y >= 0.0) {
		float h = clamp(rd.y, 0.0, 1.0);
		col = mix(horizon_color.rgb, top_color.rgb, pow(h, 0.55));
	} else {
		float h = clamp(-rd.y, 0.0, 1.0);
		col = mix(horizon_color.rgb * 0.6, ground_color.rgb, h);
	}
	COLOR = col;
}
