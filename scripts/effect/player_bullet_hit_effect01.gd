extends HitEffect
class_name PlayerBulletHitEffect

@onready var animation: AnimatedSprite2D = $AnimatedSprite2D

var _tint: Color = Color.WHITE


func _get_speed() -> float:
	return 300.0


func _setup() -> void:
	animation.play("explode")
	animation.animation_finished.connect(_finish, CONNECT_ONE_SHOT)
	var tw := create_tween()
	tw.tween_property(animation, "modulate", Color(_tint.r, _tint.g, _tint.b, 0), 0.3)


func set_tint(color: Color) -> void:
	_tint = color
	animation.modulate = color


func _on_velocity_set() -> void:
	rotation = velocity.angle()
