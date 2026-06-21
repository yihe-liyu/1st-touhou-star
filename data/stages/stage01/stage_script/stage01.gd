extends CoroutineScript
## 第一面——全难度共享

var _spawn_offset_x = 300
var _spawn_i = 0

func start(p_ctx: StageContext, p_target: Node2D = null):
	ctx = p_ctx
	if p_target:
		target = p_target
	var tl := start_timeline()
	
	var bgm: AudioStream = AssetRegistry.sounds.get("bgm1", preload("res://assets/Music/THq01_02.夜间漫步.mp3"))
	var logo_tex: Texture2D = preload("res://assets/Textures/front/logo/logo1.png")
	
	tl.at(0.0).do(func():
		ctx.audio.play_bgm(bgm)
	)

	tl.at(1.0).every(0.1).times(6).do(func():
		ctx.enemies.spawn("red_soldier", Vector2(448 + _spawn_offset_x, 0)).hp(100).hbox(32)\
			.param("target_y", 150 + _spawn_i * 60).param("bullet_speed", 400).spawn()
		_spawn_offset_x -= 100
		_spawn_i += 1
	)
	
	tl.at(3.9).do(func(): _spawn_i = 0)
	tl.at(4.0).every(0.1).times(6).do(func():
		ctx.enemies.spawn("red_soldier", Vector2(448 + _spawn_offset_x, 0)).hp(100).hbox(32)\
			.param("target_y", 150 + _spawn_i * 60).param("bullet_speed", 400).spawn()
		_spawn_offset_x += 100
		_spawn_i += 1
	)
	
	tl.at(7.0).do(func(): 
		var layer := CanvasLayer.new()
		layer.layer = 32
		var logo := TextureRect.new()
		logo.texture = logo_tex
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

	super.start(ctx, target)
