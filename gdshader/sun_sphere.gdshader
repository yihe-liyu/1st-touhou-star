shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled;
// 伪日食 3D 太阳球体（规矩圆 + 暖金，边缘略暗有体积感）
// fog_disabled：远处天空位置也不被雾衰减

void fragment() {
	vec3 n = normalize(NORMAL);
	vec3 v = normalize(VERTEX);
	float rim = abs(dot(n, -v));
	float brightness = mix(0.45, 1.0, rim);
	ALBEDO = vec3(1.0, 0.86, 0.62) * brightness;
}
