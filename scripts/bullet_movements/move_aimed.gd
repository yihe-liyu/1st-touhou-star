extends BulletMovement
class_name MoveAimed

var speed: float = 200.0
var lifetime: float = 5.0
var _timer: float = 0.0

func bind(b: Bullet):
	super.bind(b)
	speed = b.velocity.length()

func update(delta: float):
	_timer += delta
	if _timer >= lifetime:
		finished.emit()
		return

	var player = GameState.player
	if not is_instance_valid(player):
		bullet.global_position += bullet.velocity * delta
		return

	var dir = bullet.global_position.direction_to(player.global_position)
	bullet.velocity = dir * speed
	bullet.global_position += bullet.velocity * delta
	bullet.rotation = bullet.velocity.angle()
