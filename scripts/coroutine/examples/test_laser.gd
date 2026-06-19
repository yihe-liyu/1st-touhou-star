extends CreateScript
class_name TestLaserPattern

const LASER_DATA = preload("res://data/laser_data/test_laser_red.tres")
const BULLET_DATA = preload("res://data/bullet_data/test_enemy_bullet.tres")

var _phase: int = 0
var _count: int = 0

func _on_step(_ctx: StageContext) -> Variant:
	var enemy := get_parent() as Node2D
	if not enemy or not is_instance_valid(enemy):
		return false

	match _phase:
		0:
			# 六向梭形激光
			for i in 12:
				var angle := deg_to_rad(i * 30)
				var dir := Vector2.RIGHT.rotated(angle)
				ctx.bullets.fire_straight_laser(LASER_DATA, enemy.global_position, dir, 800)
			_phase = 1
			return ctx.clock.wait(1.5)

		1:
			# 激光还在飞，撒圆形弹幕
			ctx.bullets.shoot_spread(BULLET_DATA, 24, TAU, Vector2.DOWN, enemy.global_position)
			_count += 1
			if _count >= 3:
				_count = 0
				_phase = 2
				return ctx.clock.wait(1.0)
			return ctx.clock.wait(1.2)

		2:
			# 自机狙弯曲 S 形曲线激光
			var player: Player = ctx.player.get_player()
			if player and is_instance_valid(player):
				var to_p := (player.global_position - enemy.global_position).normalized()
				var curve := _make_s_curve(enemy.global_position, to_p, 500, 150)
				ctx.bullets.fire_growing_laser(LASER_DATA, enemy.global_position, curve)
			_count += 1
			if _count >= 6:
				_count = 0
				_phase = 0
				return ctx.clock.wait(3.0)  # 等激光自然飞出屏
			return ctx.clock.wait(0.8)
		_:
			return false


func _make_s_curve(start: Vector2, direction: Vector2, length: float, bend: float) -> Curve2D:
	const SAMPLES := 120
	var end := start + direction.normalized() * length
	var right := direction.orthogonal()
	# 三段贝塞尔：start → 右弯 → 弯回 → end
	var p1 := start + direction * length * 0.25 + right * bend
	var p2 := start + direction * length * 0.75 - right * bend
	var curve := Curve2D.new()
	for i in range(SAMPLES + 1):
		var t := float(i) / SAMPLES
		var u := 1.0 - t
		var pos := u * u * u * start + 3 * u * u * t * p1 + 3 * u * t * t * p2 + t * t * t * end
		curve.add_point(pos)
	return curve
