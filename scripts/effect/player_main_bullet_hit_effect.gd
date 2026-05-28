# PlayerMainBulletHitEffect.gd
extends Node2D
class_name PlayerMainBulletHitEffect01

@onready var animation: AnimatedSprite2D = $AnimatedSprite2D

var velocity: Vector2 = Vector2.ZERO
var _life: float = 0.0

func set_velocity(vel: Vector2):
	velocity = vel.normalized() * 300.0
	self.rotation = velocity.angle()

func _ready():
	animation.play("explode")
	# 安全：tween 结束后自动 queue_free
	var tw = create_tween()
	tw.tween_callback(queue_free).set_delay(0.5)

func _physics_process(delta: float) -> void:
	self.position += velocity * delta
	# 兜底：不管 tween 有没有跑，超过 2 秒强制删除
	_life += delta
	if _life > 2.0:
		queue_free()
