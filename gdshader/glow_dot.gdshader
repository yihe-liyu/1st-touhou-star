shader_type canvas_item;
// 径向渐变光球：中心亮边缘虚（任意颜色）
uniform vec4 glow_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	float d = distance(UV, vec2(0.5));
	float a = smoothstep(0.5, 0.0, d);
	COLOR = vec4(glow_color.rgb, glow_color.a * a);
}
