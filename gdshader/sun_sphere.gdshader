shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled;
// 伪日食的 3D 发光太阳本体（fog_disabled：远处也不被雾衰减）
// 中央亮白、边缘稍暗（球体体积感）

void fragment() {
	vec3 n = normalize(NORMAL);
	vec3 v = normalize(VERTEX);
	float rim = abs(dot(n, -v));
	float brightness = mix(0.5, 1.0, rim);
	ALBEDO = vec3(0.92, 0.94, 1.0) * brightness;
}
