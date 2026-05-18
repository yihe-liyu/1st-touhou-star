# MoveLinear.gd
extends RefCounted
class_name MoveLinear

var bullet: Bullet

func bind(b: Bullet):
	bullet = b

func update(delta: float):
	bullet.global_position += bullet.velocity * delta
	bullet.rotation = bullet.velocity.angle()
