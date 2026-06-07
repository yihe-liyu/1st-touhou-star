extends Sprite2D
class_name BulletFog

signal fog_finished

var duration: float = 0.3
var start_scale: float = 2.0

const BLEND_SHADER = preload("res://gdshader/bullet_fog_blend.gdshader")


func play(p_texture: Texture2D, p_tint: Color = Color.WHITE, p_mode: int = 0):
	if texture == p_texture:
		fog_finished.emit()
		return
	
	for child in get_children():
		if child.has_method("kill"):
			child.kill()
	
	texture = p_texture
	scale = Vector2(start_scale, start_scale)
	visible = true

	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2(0.5, 0.5), duration)
	
	if p_mode == 1:
		# BLEND: shader 用 fog_tint uniform，不动 modulate
		if not material or not material is ShaderMaterial:
			var mat = ShaderMaterial.new()
			mat.shader = BLEND_SHADER
			material = mat
		modulate = Color.WHITE
		material.set_shader_parameter("fog_tint", p_tint)
		tween.tween_method(_set_fog_tint_alpha.bind(material), 1.0, 0.0, duration)
	else:
		# MULTIPLY: 标准 Sprite2D，Godot 自动乘 modulate
		material = null
		modulate = p_tint
		tween.tween_property(self, "modulate:a", 0.0, duration)
	
	tween.finished.connect(_on_tween_finished)


func _set_fog_tint_alpha(a: float, mat: ShaderMaterial):
	mat.set_shader_parameter("fog_tint:a", a)


func _on_tween_finished():
	visible = false
	material = null
	texture = null
	fog_finished.emit()
