extends CreateScript
class_name TestLaserPattern

const LASER_DATA = preload("res://data/laser_data/test_laser_red.tres")
const BULLET_DATA = preload("res://data/bullet_data/test_enemy_bullet.tres")

var _phase: int = 0
var _count: int = 0

func _on_step(api: StageAPI) -> Variant:
	var enemy := get_parent() as Node2D
	if not enemy or not is_instance_valid(enemy):
		return false

	match _phase:
		0:
			# 六向梭形激光
			for i in 12:
				var angle := deg_to_rad(i * 30)
				var dir := Vector2.RIGHT.rotated(angle)
				api.fire_straight_laser(LASER_DATA, enemy.global_position, dir, 800)
			_phase = 1
			return api.seconds(1.5)

		1:
			# 激光还在飞，撒圆形弹幕
			api.shoot_spread(BULLET_DATA, 24, TAU, Vector2.DOWN, enemy.global_position)
			_count += 1
			if _count >= 3:
				_count = 0
				_phase = 0
				return api.seconds(1.0)
			return api.seconds(1.2)

		2:
			# 旋转梭形激光扫射
			api.fire_rotating_laser(LASER_DATA, enemy.global_position,
				Vector2.UP, deg_to_rad(80), 700)
			_count += 1
			if _count >= 6:
				api.clear_all_lasers()
				_phase = 3
				_count = 0
				return api.seconds(1.5)
			return api.seconds(1.0)

		3:
			# 自机狙弯曲激光（贝塞尔曲线）
			api.fire_homing_laser(LASER_DATA, enemy.global_position,
				200.0 + _count * 100.0, 600)
			_count += 1
			if _count >= 4:
				api.clear_all_lasers()
				_phase = 0
				_count = 0
				return api.seconds(1.5)
			return api.seconds(0.4)
		_:
			return false
