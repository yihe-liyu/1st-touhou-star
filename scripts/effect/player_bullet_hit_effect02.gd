# PlayerBulletHitEffect02.gd
extends Node2D
class_name PlayerBulletHitEffect02

@onready var sprite: Sprite2D = $Sprite2D

var velocity: Vector2 = Vector2.ZERO

func set_velocity(vel: Vector2):
	velocity = vel.normalized() * 750.0
	self.rotation = velocity.angle() + RNG.randf_range(-0.1, 0.1)

func _ready():
	var tw = create_tween()
	tw.tween_property(sprite, "modulate", Color(4, 4, 4, 0), 0.2)
	tw.tween_callback(queue_free).set_delay(0.3)

func _physics_process(delta: float) -> void:
	self.position += velocity * delta
