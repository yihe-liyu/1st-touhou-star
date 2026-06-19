extends StageScript

const EX_BOSS = preload("res://data/boss_data/ex_boss.tres")
const TEST_DIALOGUE = preload("res://data/dialogue/reimu/stage01_before.tres")

var _phase: int = 0

func _on_step(_ctx: StageContext) -> Variant:
	match _phase:
		0:
			ctx.play_dialogue(TEST_DIALOGUE.lines)
			AudioManager.play_bgm(preload("res://assets/Music/THq01_02.夜间漫步.mp3"), 0.0)
			_phase = 1
			return ctx.clock.wait(2.0)
		1:
			ctx.enemies.spawn_boss(EX_BOSS, Vector2(448, 160))
			_phase = 99
			return ctx.clock.wait(999)
		2:
			if ctx.enemies.all_defeated():
				return false
			return true
		_:
			return false
