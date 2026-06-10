extends HitEffect
class_name PlayerBulletHitEffect

@onready var animation: AnimatedSprite2D = $AnimatedSprite2D

var _tint: Color = Color.WHITE


func _get_speed() -> float:
	return 300.0


func _setup() -> void:
	animation.play("explode")
	var tw := create_tween()
	tw.parallel().tween_property(animation, "modulate", Color(_tint.r, _tint.g, _tint.b, 0), 0.4)
	tw.tween_callback(queue_free)


func set_tint(color: Color) -> void:
	_tint = color
	animation.modulate = color


func _on_velocity_set() -> void:
	rotation = velocity.angle()


func _process_extra(delta: float) -> void:
	scale += Vector2(10, 10) * delta
