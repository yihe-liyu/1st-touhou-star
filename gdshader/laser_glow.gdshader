shader_type canvas_item;

uniform float alpha : hint_range(0, 1) = 1.0;
uniform vec4 laser_color : source_color = vec4(1.0, 0.3, 0.2, 1.0);
uniform float glow_intensity : hint_range(0, 2) = 0.6;
uniform float warning : hint_range(0, 1) = 0.0;

void fragment() {
	// UV.x: along the line (0=root, 1=head)
	// UV.y: across the line (0.5=center, 0/1=edges)
	
	float edge_dist = abs(UV.y - 0.5) * 2.0; // 0=center, 1=edge
	
	// 核心亮线
	float core = 1.0 - smoothstep(0.0, 0.25, edge_dist);
	
	// 光晕
	float glow = exp(-edge_dist * 3.5) * glow_intensity;
	
	float a = (core + glow) * alpha;
	
	// 预警闪烁
	if (warning > 0.5) {
		a *= 0.3 + 0.4 * sin(TIME * 12.0);
	}
	
	COLOR = vec4(laser_color.rgb, clamp(a, 0.0, 1.0));
}
