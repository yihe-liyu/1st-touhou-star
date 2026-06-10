extends HitEffect
class_name EnemyBulletClear

@onready var sprite: Sprite2D = $Sprite2D

var _tween: Tween


func _ready() -> void:
	sprite.modulate = Color.RED
	sprite.modulate.a = 0.8


func _get_speed() -> float:
	return 0.0


func _setup() -> void:
	print("[EnemyBulletClear] _setup pos=", global_position, " tint=", sprite.modulate)
	
	if _tween and _tween.is_valid():
		_tween.kill()
	
	sprite.scale = Vector2.ONE
	sprite.modulate = sprite.modulate  # keep current color
	sprite.modulate.a = 0.8
	sprite.visible = true
	
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.set_trans(Tween.TRANS_CUBIC)
	_tween.set_ease(Tween.EASE_IN)
	_tween.tween_property(sprite, "scale", Vector2(0.2, 0.2), 0.6)
	_tween.tween_property(sprite, "modulate:a", 0.0, 0.6)
	_tween.tween_callback(_finish)


func set_tint(color: Color) -> void:
	print("[EnemyBulletClear] set_tint ", color)
	sprite.modulate = color
	sprite.modulate.a = 0.8


func _get_life_limit() -> float:
	return 1.5
