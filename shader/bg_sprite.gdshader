// bg_sprite.gdshader
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled;

uniform sampler2D texture_albedo : source_color;
uniform vec4 tint : source_color = vec4(1.0);

void fragment() {
    vec4 tex = texture(texture_albedo, UV) * tint;
    ALBEDO = tex.rgb;
    ALPHA = tex.a;
}