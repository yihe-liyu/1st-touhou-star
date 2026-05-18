// bg_ground.gdshader
shader_type spatial;
render_mode unshaded, blend_mix;

uniform sampler2D base_texture : source_color, filter_linear_mipmap;
uniform vec2 scroll_speed = vec2(0.0, 0.5);
uniform float grid_scale = 20.0;
uniform float grid_line_width = 0.03;
uniform vec4 grid_color : source_color = vec4(0.3, 0.5, 1.0, 0.5);
uniform vec4 base_tint : source_color = vec4(0.05, 0.05, 0.15, 1.0);
uniform float camera_speed_mult = 1.0;
uniform float fov_stretch = 0.0;
uniform float roll = 0.0;
uniform float tilt_x = 0.0;
uniform float tilt_y = 0.0;

void vertex() {
    float rz = roll * 0.3;
    float cos_r = cos(rz);
    float sin_r = sin(rz);
    vec2 rotated = vec2(
        VERTEX.x * cos_r - VERTEX.y * sin_r,
        VERTEX.x * sin_r + VERTEX.y * cos_r
    );
    VERTEX.x = rotated.x;
    VERTEX.y = rotated.y + VERTEX.z * tilt_x * 0.5;
    VERTEX.x -= VERTEX.z * tilt_y * 0.5;
    VERTEX.y *= 1.0 + fov_stretch * 0.3;
    VERTEX.x *= 1.0 - fov_stretch * 0.15;
}

void fragment() {
    vec2 scrolled_uv = UV * grid_scale + scroll_speed * camera_speed_mult * TIME;
    vec4 base = texture(base_texture, scrolled_uv) * base_tint;
    vec2 grid = abs(fract(scrolled_uv - 0.5) - 0.5) * 2.0;
    float line = min(grid.x, grid.y);
    float grid_alpha = 1.0 - smoothstep(0.0, grid_line_width, line);
    vec3 color = mix(base.rgb, grid_color.rgb, grid_alpha * grid_color.a);
    float alpha = max(base.a, grid_alpha * grid_color.a);
    ALBEDO = color;
    ALPHA = alpha;
}