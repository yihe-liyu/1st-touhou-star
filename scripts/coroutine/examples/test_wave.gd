extends StageScript
class_name TestLevel

const EX_BOSS = preload("res://data/boss_data/ex_boss.tres")

var _phase: int = 0

func _on_step(api: StageAPI) -> Variant:
	match _phase:
		0:
			AudioManager.play_bgm(preload("res://assets/Music/THq01_02.夜间漫步.mp3"), 0.0)
			_phase = 1
			return api.seconds(2.0)
		1:
			api.spawn_boss(EX_BOSS, Vector2(448, 160))
			_phase = 99
			return api.seconds(999)
		2:
			if api.all_defeated():
				return false
			return true
		_:
			return false
