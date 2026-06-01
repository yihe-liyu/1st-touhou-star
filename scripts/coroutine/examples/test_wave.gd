extends StageScript
class_name TestLevel

const ENEMY_DATA = preload("res://data/enemy_data/test_enemy_data.tres")
const LASER_ENEMY_DATA = preload("res://data/enemy_data/test_enemy_laser.tres")

var _phase: int = 0

func _on_step(api: StageAPI) -> Variant:
	
	AudioManager.play_bgm(preload("res://assets/Music/THq01_12.不尽记忆的天空.mp3"), 1.0)
	
	match _phase:
		0:
			api.spawn_enemy(ENEMY_DATA, Vector2(448, 50))
			_phase = 1
			return api.seconds(3.0)
		1:
			if api.all_defeated():
				return false
			return true
		_:
			return false
