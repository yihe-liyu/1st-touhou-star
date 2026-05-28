extends StageScript
class_name TestLevel

const ENEMY_DATA = preload("res://data/enemy_data/test_enemy_data.tres")
const LASER_ENEMY_DATA = preload("res://data/enemy_data/test_enemy_laser.tres")

var _phase: int = 0
var _wait_time: float = 0.0

func _on_step(api: StageAPI) -> Variant:
	match _phase:
		0:
			api.spawn_enemy(ENEMY_DATA, Vector2(640, -50))
			api.spawn_enemy(LASER_ENEMY_DATA, Vector2(400, -50))
			_phase = 1
			return api.seconds(3.0)
		1:
			api.spawn_enemy(ENEMY_DATA, Vector2(300, -50))
			_phase = 2
			return api.seconds(3.0)
		2:
			api.spawn_enemy(ENEMY_DATA, Vector2(500, -50))
			_phase = 3
			return api.seconds(15.0)  # 给足时间看激光
		3:
			# 等敌人都死了或超时，再清场结束
			if api.all_defeated():
				api.clear_all_lasers()
				return false
			return true  # 继续等
		_:
			return false
