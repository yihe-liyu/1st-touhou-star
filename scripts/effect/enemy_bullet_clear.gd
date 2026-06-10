extends HitEffect
class_name EnemyBulletClear

@onready var sprite: Sprite2D = $Sprite2D


func _get_speed() -> float:
	return 0.0  # 不移动


func _setup() -> void:
	sprite.scale = Vector2(0.3, 0.3)
	sprite.modulate = Color.WHITE
	
	# 弹开 → 缩小 → 淡出
	var tw := create_tween().set_parallel(true)
	tw.set_trans(Tween.TRANS_CUBIC)
	tw.set_ease(Tween.EASE_OUT)
	tw.tween_property(sprite, "scale", Vector2(1.2, 1.2), 0.15)
	tw.tween_property(sprite, "modulate:a", 0.3, 0.15)
	tw.tween_callback(func():
		var tw2 := create_tween().set_parallel(true)
		tw2.set_trans(Tween.TRANS_CUBIC)
		tw2.set_ease(Tween.EASE_IN)
		tw2.tween_property(sprite, "scale", Vector2(0.1, 0.1), 0.25)
		tw2.tween_property(sprite, "modulate:a", 0.0, 0.25)
		tw2.tween_callback(_finish)
	)


func set_tint(color: Color) -> void:
	sprite.modulate = color


func _get_life_limit() -> float:
	return 1.0
