shader_type canvas_item;
render_mode blend_mix;

// 全屏蒙眼雾（2D 层）：玩家被蒙眼 → 整个画面蒙一层流动的暗雾
// 太阳屏幕位置处更浓（噪声扰动的不规则浓雾 = 专门遮太阳）

uniform sampler2D noise_tex;                                   // 值噪声云斑纹理
uniform float fog_dark : hint_range(0.0, 1.0) = 0.5;           // 整体蒙眼浓度
uniform vec2 sun_pos = vec2(0.5, 0.18);                        // 太阳屏幕位置（归一化）
uniform float sun_fog_radius : hint_range(0.0, 0.5) = 0.16;    // 太阳处雾团范围
uniform float sun_fog_extra : hint_range(0.0, 1.0) = 0.45;     // 太阳处额外浓度
uniform float flow_speed : hint_range(0.0, 0.5) = 0.03;        // 流动速度
uniform float noise_scale = 1.4;                               // 云斑大小
uniform vec3 fog_color : source_color = vec3(0.02, 0.02, 0.03); // 雾色（暗蓝灰）

void fragment() {
	// 流动的云斑（噪声纹理平铺采样）
	vec2 q = UV * noise_scale + vec2(TIME * flow_speed, TIME * flow_speed * 0.7);
	vec4 n = texture(noise_tex, fract(q));
	// 整体蒙眼：暗雾带着云斑不均匀（黑蒙蒙）
	float fog = fog_dark * (0.55 + 0.45 * n.r);
	// 太阳处更浓：距离衰减 + 噪声扰动（不规则浓雾遮太阳）
	float ds = distance(UV, sun_pos);
	float sun_mask = exp(-ds * ds / max(sun_fog_radius * sun_fog_radius, 0.001));
	fog += sun_mask * sun_fog_extra * (0.55 + 0.45 * n.g);
	fog = clamp(fog, 0.0, 0.9);
	COLOR = vec4(fog_color, fog);
}
