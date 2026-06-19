extends StageScript
## 第一面——全难度共享

const REIMU_BEFORE_DIALOGUE = preload("res://data/dialogue/reimu/stage01_before.tres")
const LOGO = preload("res://assets/Textures/front/logo/logo1.png")

const ENEMY01 = preload("res://data/stages/stage01/enemy/enemy01.tres")

var _spawn_offset_x = 300
var _spawn_i = 0

func start_stage(p_ctx: StageContext):
	ctx = p_ctx
	var tl := start_timeline()
	
	tl.at(0.0).do(func():
		AudioManager.play_bgm(preload("res://assets/Music/THq01_02.夜间漫步.mp3"), 0.0)
	)

	# 难度差异：Hard 多一波
	var wave_count: int = diff_pick([6, 6, 8])
	tl.at(1.0).every(0.1).times(wave_count).do(func():
		var e := ctx.enemies.spawn_enemy(ENEMY01, Vector2(448 + _spawn_offset_x, 0), false)
		e.move_script.target_y = 150 + _spawn_i * 60
		e.start()
		_spawn_offset_x -= 100
		_spawn_i += 1
	)
	
	if wave_count > 0:
		tl.at(3.9).do(func(): _spawn_i = 0)
		tl.at(4.0).every(0.1).times(wave_count).do(func():
			var e := ctx.enemies.spawn_enemy(ENEMY01, Vector2(448 + _spawn_offset_x, 0), false)
			e.move_script.target_y = 150 + _spawn_i * 60
			e.start()
			_spawn_offset_x += 100
			_spawn_i += 1
		)
	
	tl.at(7.0).do(func(): 
		# LOGO
		var layer := CanvasLayer.new()
		layer.layer = 32
		var logo := TextureRect.new()
		logo.texture = LOGO
		logo.global_position = Vector2(448 - (logo.texture.get_size().x / 2), 280)
		logo.modulate.a = 0.0
		layer.add_child(logo)
		add_child(layer)
		var t := create_tween()
		t.tween_property(logo, "modulate:a", 1.0, 2.0)
		t.tween_interval(3.0)
		t.tween_property(logo, "modulate:a", 0.0, 1.0)
		t.tween_callback(layer.queue_free)
	)

	super.start_stage(p_ctx)
