# PlayerBulletHitEffect01.gd
extends Node2D
class_name PlayerBulletHitEffect

@onready var animation: AnimatedSprite2D = $AnimatedSprite2D

var velocity: Vector2 = Vector2.ZERO
var _life: float = 0.0

func set_velocity(vel: Vector2):
	velocity = vel.normalized() * 300.0
	self.rotation = velocity.angle()

func _ready():
	animation.play("explode")
	var tw = create_tween()
	tw.parallel().tween_property(animation, "modulate", Color(1, 1, 1, 0), 0.4)
	tw.tween_callback(queue_free)

func _physics_process(delta: float) -> void:
	self.position += velocity * delta
	self.scale += Vector2(10, 10) * delta
	_life += delta
	if _life > 2.0:
		queue_free()
