# PlayerBulletHitEffect.gd
extends Node2D
class_name PlayerBulletHitEffect

@onready var animation: AnimatedSprite2D = $AnimatedSprite2D

var velocity: Vector2 = Vector2.ZERO

func set_velocity(vel: Vector2):
	velocity = vel.normalized() * 300.0
	# 让特效朝向子弹飞行方向
	self.rotation = velocity.angle()

func _ready():
	animation.play("explode")
	await animation.animation_finished
	queue_free()

func _physics_process(delta: float) -> void:
	self.position += velocity * delta
	self.rotation = velocity.angle()
