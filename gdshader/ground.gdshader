shader_type spatial;
render_mode unshaded;

uniform sampler2D ground_texture : source_color;
uniform vec2 tiling = vec2(4.0, 4.0);

void vertex() {
	// Called for every vertex the material is visible on.
}

void fragment() {
	vec2 uv = UV * tiling;
	uv.y -= TIME * 0.1;
	
	vec3 base = texture(ground_texture, uv).rgb;
	
	ALBEDO = base;
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
