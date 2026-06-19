extends StageScript
## 第一面 Easy —— 时间线版

const REIMU_BEFORE_DIALOGUE = preload("res://data/dialogue/reimu/stage01_before.tres")

const ENEMY01 = preload("res://data/stages/stage01/enemy/enemy01.tres")

var _spawn_offset_x = 300
var _spawn_i = 0

func start_stage(p_ctx: StageContext):
	ctx = p_ctx
	var tl := start_timeline()

	tl.at(0.0); tl.do(func():
		AudioManager.play_bgm(preload("res://assets/Music/THq01_02.夜间漫步.mp3"), 0.0)
	)
	
	tl.at(1.0); tl.every(0.5); tl.times(12); tl.do(func():
		var e := ctx.enemies.spawn_enemy(ENEMY01, Vector2(448 + _spawn_offset_x, 0), false)
		e.move_script.target_y = 150 + _spawn_i * 30
		e.start()
		_spawn_offset_x -= 50
		_spawn_i += 1
	)
	
	#tl.at(1.0); tl.do(func():
		#ctx.play_dialogue(REIMU_BEFORE_DIALOGUE.lines)
	#)

	super.start_stage(p_ctx)
