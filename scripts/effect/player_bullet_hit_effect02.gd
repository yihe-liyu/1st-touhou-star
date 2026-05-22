# PlayerBulletHitEffect.gd
extends Node2D
class_name PlayerBulletHitEffect02

@onready var sprite: Sprite2D = $Sprite2D

var velocity: Vector2 = Vector2.ZERO

func set_velocity(vel: Vector2):
	velocity = vel.normalized() * 300.0
	self.rotation = velocity.angle() + RNG.randf_range(-0.1, 0.1)

func _ready():
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color(3, 3, 3, 0.5), 0.1)
	await tween.finished
	queue_free()

func _physics_process(delta: float) -> void:
	self.position += velocity * delta
