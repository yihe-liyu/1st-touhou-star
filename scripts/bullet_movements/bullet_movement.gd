extends RefCounted
class_name BulletMovement

signal finished()

var bullet: Bullet

func bind(b: Bullet):
	bullet = b

func update(delta: float):
	pass
