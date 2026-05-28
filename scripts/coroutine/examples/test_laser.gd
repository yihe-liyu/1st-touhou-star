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
			# 六向激光开花
			for i in 6:
				var angle := deg_to_rad(i * 60)
				var dir := Vector2.RIGHT.rotated(angle)
				api.fire_straight_laser(LASER_DATA, enemy.global_position, dir, 500)
			_phase = 1
			return api.seconds(1.0)  # 激光正在生长…
		
		1:
			# 激光激活时，撒一圈弹
			api.shoot_spread(BULLET_DATA, 24, TAU, Vector2.DOWN, enemy.global_position)
			_count += 1
			if _count >= 3:
				api.clear_all_lasers()
				_phase = 2
				_count = 0
				return api.seconds(1.5)
			return api.seconds(1.2)
		
		2:
			# 旋转激光扫射
			api.fire_rotating_laser(LASER_DATA, enemy.global_position,
				Vector2.UP, deg_to_rad(60), 500)
			_count += 1
			if _count >= 4:
				api.clear_all_lasers()
				_phase = 0
				_count = 0
				return api.seconds(2.0)
			return api.seconds(2.5)
		_:
			return false
