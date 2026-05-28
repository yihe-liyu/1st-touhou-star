# PlayerMainBulletHitEffect.gd
extends Node2D
class_name PlayerMainBulletHitEffect01

@onready var animation: AnimatedSprite2D = $AnimatedSprite2D

var velocity: Vector2 = Vector2.ZERO

func set_velocity(vel: Vector2):
	velocity = vel.normalized() * 300.0
	# 让特效朝向子弹飞行方向
	self.rotation = velocity.angle()

func _ready():
	animation.play("explode")
	# 固定延时释放，不依赖信号（防止掉帧时内存泄漏）
	var tw = create_tween()
	tw.tween_callback(queue_free).set_delay(0.5)

func _physics_process(delta: float) -> void:
	self.position += velocity * delta
