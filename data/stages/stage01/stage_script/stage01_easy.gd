extends StageScript
## 第一面 Easy —— 时间线版

const REIMU_BEFORE_DIALOGUE = preload("res://data/dialogue/reimu/stage01_before.tres")
const EX_BOSS = preload("res://data/boss_data/ex_boss.tres")
const TimelineClass = preload("res://scripts/coroutine/base/timeline.gd")

var _tl


func _on_step(_ctx: StageContext) -> Variant:
	_tl.tick(get_physics_process_delta_time())
	return true


func start_stage(p_ctx: StageContext):
	ctx = p_ctx
	_tl = TimelineClass.new(ctx)

	_tl.at(0.0); _tl.do(func():
		AudioManager.play_bgm(preload("res://assets/Music/THq01_02.夜间漫步.mp3"), 0.0)
	)
	_tl.at(1.0); _tl.do(func():
		ctx.play_dialogue(REIMU_BEFORE_DIALOGUE.lines)
	)
	_tl.at(3.0); _tl.do(func():
		ctx.enemies.spawn_boss(EX_BOSS, Vector2(448, 160))
	)

	super.start_stage(p_ctx)
