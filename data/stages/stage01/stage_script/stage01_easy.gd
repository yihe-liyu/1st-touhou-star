extends StageScript
## 第一面 Easy —— 时间线版

const REIMU_BEFORE_DIALOGUE = preload("res://data/dialogue/reimu/stage01_before.tres")
const EX_BOSS = preload("res://data/boss_data/ex_boss.tres")


func start_stage(p_ctx: StageContext):
	ctx = p_ctx
	var tl := start_timeline()

	tl.at(0.0); tl.do(func():
		AudioManager.play_bgm(preload("res://assets/Music/THq01_02.夜间漫步.mp3"), 0.0)
	)
	tl.at(1.0); tl.do(func():
		ctx.play_dialogue(REIMU_BEFORE_DIALOGUE.lines)
	)
	tl.at(3.0); tl.do(func():
		ctx.enemies.spawn_boss(EX_BOSS, Vector2(448, 160))
	)

	super.start_stage(p_ctx)
