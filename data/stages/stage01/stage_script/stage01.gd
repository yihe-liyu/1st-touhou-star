extends StageScript
## 第一面——全难度共享

var _spawn_offset_x = 300
var _spawn_i = 0

func start_stage(p_ctx: StageContext):
	ctx = p_ctx
	var tl := start_timeline()
	
	var bgm: AudioStream = AssetRegistry.sounds.get("bgm1", preload("res://assets/Music/THq01_02.夜间漫步.mp3"))
	var logo_img: Texture2D = AssetRegistry.ui_textures["logo1"]
	
	tl.at(0.0).do(func():
		AudioManager.play_bgm(bgm, 0.0)
	)

	tl.at(1.0).every(0.1).times(6).do(func():
		ctx.enemies.spawn("red_soldier",
			Vector2(448 + _spawn_offset_x, 0),
			{"target_y": 150 + _spawn_i * 60, "bullet_speed": 400, "bullet_count": 3}
		)
		_spawn_offset_x -= 100
		_spawn_i += 1
	)
	
	tl.at(3.9).do(func(): _spawn_i = 0)
	tl.at(4.0).every(0.1).times(6).do(func():
		ctx.enemies.spawn("red_soldier",
			Vector2(448 + _spawn_offset_x, 0),
			{"target_y": 150 + _spawn_i * 60, "bullet_speed": 400, "bullet_count": 3}
		)
		_spawn_offset_x += 100
		_spawn_i += 1
	)
	
	tl.at(7.0).do(func(): 
		var layer := CanvasLayer.new()
		layer.layer = 32
		var logo := TextureRect.new()
		logo.texture = logo_img
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
