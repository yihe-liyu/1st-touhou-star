shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled, blend_mix;

// Sprite3D 太阳用：极简——只采样纹理 + 雾豁免（雾只该遮太阳周围，不让雾吃掉太阳本体）
// 形状（黑圆+漏光+光晕）全部画在纹理里（Image 逐像素 = 绝对正圆）

uniform sampler2D sun_tex;

void fragment() {
	vec4 c = texture(sun_tex, UV);
	ALBEDO = c.rgb;
	EMISSION = c.rgb * 4.0;  // HDR 超亮 → Environment glow 泛光（辉光）
	ALPHA = c.a;
}
