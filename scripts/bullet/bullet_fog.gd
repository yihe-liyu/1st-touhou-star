extends Sprite2D
class_name BulletFog

var duration: float = 0.4
var start_scale: float = 2.0

var _tween: Tween

func play(p_texture: Texture2D) -> Tween:
	if _tween and _tween.is_valid():
		_tween.kill()

	texture = p_texture
	modulate.a = 1.0
	scale = Vector2(start_scale, start_scale)
	visible = true

	_tween = create_tween()
	_tween.set_ease(Tween.EASE_OUT)
	_tween.set_trans(Tween.TRANS_QUAD)
	_tween.tween_property(self, "scale", Vector2.ZERO, duration)
	_tween.parallel().tween_property(self, "modulate:a", 0.0, duration * 0.6)
	return _tween
