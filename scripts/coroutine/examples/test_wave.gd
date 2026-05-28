extends StageScript
class_name TestLevel

const ENEMY_DATA = preload("res://data/enemy_data/test_enemy_data.tres")

var _phase: int = 0

func _on_step(api: StageAPI) -> Variant:
	match _phase:
		0:
			api.spawn_enemy(ENEMY_DATA, Vector2(640, -50))
			_phase = 1
			return api.seconds(3.0)
		1:
			api.spawn_enemy(ENEMY_DATA, Vector2(300, -50))
			_phase = 2
			return api.seconds(3.0)
		2:
			api.spawn_enemy(ENEMY_DATA, Vector2(500, -50))
			_phase = 3
			return api.seconds(3.0)
		_:
			return false
