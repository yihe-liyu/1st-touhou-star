extends Sprite2D
class_name BulletFog

signal fog_finished

var duration: float = 0.3
var start_scale: float = 2.0
var _tween: Tween

const BLEND_SHADER = preload("res://gdshader/bullet_fog_blend.gdshader")


func play(p_texture: Texture2D, p_tint: Color = Color.WHITE):
	# 先杀旧 tween，防残留动画捣乱
	if _tween and _tween.is_valid():
		_tween.kill()
	
	if texture == p_texture:
		fog_finished.emit()
		return
	
	for child in get_children():
		if child.has_method("kill"):
			child.kill()
	
	texture = p_texture
	scale = Vector2(start_scale, start_scale)
	visible = true
	
	if not material or not material is ShaderMaterial:
		var mat = ShaderMaterial.new()
		mat.shader = BLEND_SHADER
		material = mat
	# fog_tint 只设一次（alpha 固定 1），淡出改用 modulate.a（普通属性 tween，无每帧材质上传）
	modulate = Color(1.0, 1.0, 1.0, p_tint.a)
	material.set_shader_parameter("fog_tint", Color(p_tint.r, p_tint.g, p_tint.b, 1.0))

	_tween = create_tween()
	_tween.set_ease(Tween.EASE_OUT)
	_tween.set_trans(Tween.TRANS_QUAD)
	_tween.set_parallel(true)
	_tween.tween_property(self, "scale", Vector2(0.5, 0.5), duration)
	_tween.tween_property(self, "modulate:a", 0.0, duration)
	_tween.finished.connect(_on_tween_finished)


func _on_tween_finished():
	visible = false
	material = null
	texture = null
	fog_finished.emit()
