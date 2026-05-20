# MoveLinear.gd
extends BulletMovement
class_name MoveLinear

func update(delta: float):
	bullet.global_position += bullet.velocity * delta
	bullet.rotation = bullet.velocity.angle()
