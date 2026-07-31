extends HitEffect
class_name PlayerBulletHitEffect02

@onready var sprite: Sprite2D = $Sprite2D

var _tint: Color = Color.WHITE


func _get_speed() -> float:
	return 750.0


func _setup() -> void:
	var tw := create_tween()
	tw.tween_property(sprite, "modulate:a", 0, 0.2)
	tw.tween_callback(_finish)


func set_tint(color: Color) -> void:
	_tint = color
	sprite.modulate = color


func _on_velocity_set() -> void:
	rotation = velocity.angle() + RNG.randf_range(-0.1, 0.1)
