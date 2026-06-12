extends StageScript
class_name TestLevel

const ENEMY_DATA = preload("res://data/enemy_data/test_enemy_data.tres")
const LASER_ENEMY_DATA = preload("res://data/enemy_data/test_enemy_laser.tres")

var _phase: int = 0

func _on_step(api: StageAPI) -> Variant:
	match _phase:
		0:
			AudioManager.play_bgm(preload("res://assets/Music/THq01_02.夜间漫步.mp3"), 0.0)
			_phase = 1
			return api.seconds(2.0)
		1:
			api.spawn_enemy(ENEMY_DATA, Vector2(448, 100))
			_phase = 2
			return api.seconds(3.0)
		2:
			if api.all_defeated():
				return false
			return true
		_:
			return false
