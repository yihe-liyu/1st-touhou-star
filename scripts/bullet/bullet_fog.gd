extends Sprite2D
class_name BulletFog

signal fog_finished

var duration: float = 0.3
var start_scale: float = 2.0

func play(p_texture: Texture2D):
	if texture == p_texture:
		fog_finished.emit()  # 同样纹理，直接完成
		return
	
	# 杀旧 tween 防冲突
	for child in get_children():
		if child.has_method("kill"):
			child.kill()
	
	texture = p_texture
	modulate.a = 1.0
	scale = Vector2(start_scale, start_scale)
	visible = true

	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2(0.5, 0.5), duration)
	tween.tween_property(self, "modulate:a", 0.0, duration)
	tween.finished.connect(_on_tween_finished)

func _on_tween_finished():
	visible = false
	texture = null
	fog_finished.emit()
