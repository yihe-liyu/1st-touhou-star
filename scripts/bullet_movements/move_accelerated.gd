extends BulletMovement
class_name MoveAccelerated

var acceleration: float = 50.0

func bind(b: Bullet):
	super.bind(b)

func update(delta: float):
	var speed = bullet.velocity.length()
	var new_speed = speed + acceleration * delta
	if new_speed <= 0.0:
		bullet.velocity = Vector2.ZERO
		finished.emit()
		return
	var dir = bullet.velocity.normalized()
	bullet.velocity = dir * new_speed
	bullet.global_position += bullet.velocity * delta
	bullet.rotation = bullet.velocity.angle()
