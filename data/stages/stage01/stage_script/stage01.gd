extends CoroutineScript
## 第一面——全难度共享

const ENEMY01 = preload("res://data/stages/stage01/coroutine_script/enemy01.gd")
const ENEMY02 = preload("res://data/stages/stage01/coroutine_script/enemy02.gd")
const DIALOGUE01 = preload("res://data/dialogue/reimu/stage01_before.tres")
const BOSS_POINT = preload("res://data/enemy_visual/boss/stage01/kamorui.tscn")

func start(p_ctx: StageContext, p_target: Node2D = null):
	ctx = p_ctx
	if p_target:
		target = p_target
	var tl := start_timeline()

	var bgm: AudioStream = AssetRegistry.sounds["stage1"]
	var logo_tex: Texture2D = preload("res://assets/Textures/front/logo/logo1.png")

	tl.at(0.0).do(func(): ctx.audio.play_bgm(bgm))

	for i in 7:
		tl.at(1.0 + i * 0.1).do(func():
			EnemyData.new().script(ENEMY01)\
				.pos(Vector2(448 + 300 - i * 90, 0)).red_little_fairy()\
				.param("target_y", 150 + i * 50).spawn()
		)

	for i in 7:
		tl.at(4.0 + i * 0.1).do(func():
			EnemyData.new().script(ENEMY01)\
				.pos(Vector2(448 - 300 + i * 90, 0)).red_little_fairy()\
				.param("target_y", 150 + i * 50).spawn()
		)

	# Logo
	tl.at(7.0).do(func():
		var layer := CanvasLayer.new()
		layer.layer = 32
		var logo := TextureRect.new()
		logo.texture = logo_tex
		logo.global_position = Vector2(448 - (logo.texture.get_size().x / 2), 250)
		logo.modulate.a = 0.0
		layer.add_child(logo)
		add_child(layer)
		var t := create_tween()
		t.tween_property(logo, "modulate:a", 1.0, 2.0)
		t.tween_interval(3.0)
		t.tween_property(logo, "modulate:a", 0.0, 1.0)
		t.tween_callback(layer.queue_free)
	)

	for i in 6:
		var local_enemy = EnemyData.new().script(ENEMY02)
		var delta_time = 3
		var target_y = 175 + i * 50
		if i % 2 == 0:
			tl.at(11.0 + i * delta_time).do(func():
				local_enemy.red_middle_fairy()\
				.pos(Vector2(0, target_y))\
				.param("target_pos", Vector2(448 + 100 + i * 25, target_y)).spawn()
			)
		else:
			tl.at(11.0 + i * delta_time).do(func():
				local_enemy.blue_middle_fairy()\
				.pos(Vector2(914, target_y))\
				.param("target_pos", Vector2(448 - 100 - i * 25, target_y)).spawn()
			)
	
	for i in 7:
		tl.at(20.0 + i * 0.1).do(func():
			EnemyData.new().script(ENEMY01)\
				.pos(Vector2(448 + 300 - i * 90, 0)).red_little_fairy()\
				.param("target_y", 360 + i * 40)\
				.param("is_stage2", false)\
				.param("rate", 4).spawn()
			EnemyData.new().script(ENEMY01)\
				.pos(Vector2(448 - 300 + i * 90, 0)).red_little_fairy()\
				.param("target_y", 360 + i * 40)\
				.param("is_stage2", false)\
				.param("rate", 4).spawn()
		)

	for i in 7:
		tl.at(28.0 + i * 0.1).do(func():
			EnemyData.new().script(ENEMY01)\
				.pos(Vector2(448 + 300 - i * 90, 0)).red_little_fairy()\
				.param("target_y", 200 + i * 40)\
				.param("is_stage2", false)\
				.param("rate", 4).spawn()
			EnemyData.new().script(ENEMY01)\
				.pos(Vector2(448 - 300 + i * 90, 0)).red_little_fairy()\
				.param("target_y", 200 + i * 40)\
				.param("is_stage2", false)\
				.param("rate", 4).spawn()
		)
	
	var kamorui_mid = BossData.new().name("？？？")\
		.look(BOSS_POINT)\
		.phase(preload("res://data/stages/stage01/phase/E_01.tres"))
	
	tl.at(35).spawn_boss(kamorui_mid, Vector2(448, 250))
	
	#tl.at(35).do(func(): ctx.dialogue.play(DIALOGUE01.lines))
	
	super.start(ctx, target)
