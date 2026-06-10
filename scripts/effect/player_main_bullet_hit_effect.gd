extends HitEffect
class_name PlayerMainBulletHitEffect01

@onready var animation: AnimatedSprite2D = $AnimatedSprite2D


func _get_speed() -> float:
	return 300.0


func _setup() -> void:
	animation.play("explode")
	var tw := create_tween()
	tw.tween_callback(queue_free).set_delay(0.5)


func set_tint(color: Color) -> void:
	animation.modulate = color


func _on_velocity_set() -> void:
	rotation = velocity.angle()
