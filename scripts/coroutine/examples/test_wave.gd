extends StageScript
class_name TestLevel

const ENEMY_DATA = preload("res://data/enemy_data/test_enemy_data.tres")
const LASER_ENEMY_DATA = preload("res://data/enemy_data/test_enemy_laser.tres")
const BOSS_VISUAL = preload("res://scenes/enemy_visual_test.tscn")
const BOSS_MOVE = preload("res://scripts/coroutine/examples/boss_move_test.gd")
const BOSS_SHOOT = preload("res://scripts/coroutine/examples/boss_shoot_test.gd")

var _phase: int = 0

func _on_step(api: StageAPI) -> Variant:
	match _phase:
		0:
			AudioManager.play_bgm(preload("res://assets/Music/THq01_02.夜间漫步.mp3"), 0.0)
			_phase = 1
			return api.seconds(2.0)
		1:
			_spawn_boss(api)
			_phase = 99
			return api.seconds(999)
		2:
			if api.all_defeated():
				return false
			return true
		_:
			return false

func _spawn_boss(api: StageAPI) -> void:
	var phase := PhaseData.new()
	phase.name = "测试「First Spell」"
	phase.bonus = 50000
	phase.time_limit = 60.0
	phase.hp = 1000
	phase.move_script = BOSS_MOVE
	phase.shoot_script = BOSS_SHOOT
	
	var bd := BossData.new()
	bd.visual = BOSS_VISUAL
	bd.phases = [phase]
	bd.score_value = 10000
	
	api.spawn_boss(bd, Vector2(448, 160))
