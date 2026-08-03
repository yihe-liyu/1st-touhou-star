extends CoroutineScript
## 第一面——新的 Timeline API

const ENEMY01 = preload("res://data/stages/stage01/coroutine_script/enemy01.gd")
const ENEMY02 = preload("res://data/stages/stage01/coroutine_script/enemy02.gd")
const FLY_AWAY = preload("res://data/stages/stage01/coroutine_script/fly_away.gd")
const DIALOGUE01 = preload("res://data/dialogue/reimu/stage01_before.tres")
const BOSS_POINT = preload("res://data/enemy_visual/boss/stage01/kamorui.tscn")
const NON_01 = preload("res://data/stages/stage01/phase/non_01.tres")

func start(p_ctx: StageContext, p_target: Node2D = null):
	ctx = p_ctx
	if p_target: target = p_target
	var tl := start_timeline()
	var bgm: AudioStream = AssetRegistry.get_bgm("stage1")
	var logo_tex: Texture2D = preload("res://assets/Textures/front/logo/logo1.png")

	# 0s: BGM
	tl.at(0.0).play_bgm(bgm)

	# 1~3s: 妖精波 (左右交替)
	for i in 7:
		tl.at(1.0 + i * 0.1).do(func():
			EnemyData.new().with_script(ENEMY01)\
				.pos(Vector2(GameConfig.FIELD_CENTER_X + 300 - i * 90, 0)).red_little_fairy()\
				.param("target_y", 150 + i * 50).spawn(ctx)
		)
	for i in 7:
		tl.at(4.0 + i * 0.1).do(func():
			EnemyData.new().with_script(ENEMY01)\
				.pos(Vector2(GameConfig.FIELD_CENTER_X - 300 + i * 90, 0)).red_little_fairy()\
				.param("target_y", 150 + i * 50).spawn(ctx)
		)

	# 7s: Logo
	tl.at(7.0).do(func():
		var layer := CanvasLayer.new()
		layer.layer = 32
		var logo := TextureRect.new()
		logo.texture = logo_tex
		logo.global_position = Vector2(GameConfig.FIELD_CENTER_X - (logo.texture.get_size().x / 2), 250)
		logo.modulate.a = 0.0
		layer.add_child(logo)
		add_child(layer)
		var t := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
		t.tween_property(logo, "modulate:a", 1.0, 2.0)
		t.tween_interval(3.0)
		t.tween_property(logo, "modulate:a", 0.0, 1.0)
		t.tween_callback(layer.queue_free)
	)

	# 11~26s: 中线妖精波
	for i in 6:
		var local_enemy = EnemyData.new().with_script(ENEMY02)
		var target_y = 175 + i * 50
		if i % 2 == 0:
			tl.at(11.0 + i * 3.0).do(func():
				local_enemy.red_middle_fairy()\
				.pos(Vector2(0, target_y))\
				.param("target_pos", Vector2(GameConfig.FIELD_CENTER_X + 100 + i * 25, target_y)).spawn(ctx)
			)
		else:
			tl.at(11.0 + i * 3.0).do(func():
				local_enemy.blue_middle_fairy()\
				.pos(Vector2(914, target_y))\
				.param("target_pos", Vector2(GameConfig.FIELD_CENTER_X - 100 - i * 25, target_y)).spawn(ctx)
			)

	for i in 7:
		tl.at(17.0 + i * 0.5).do(func():
			EnemyData.new().with_script(ENEMY01)\
				.pos(Vector2(GameConfig.FIELD_CENTER_X + 300 - i * 90, 0)).red_little_fairy()\
				.param("target_y", 360 + i * 40)\
				.param("rate", 4).param("heavy_wave", false).spawn(ctx)
			EnemyData.new().with_script(ENEMY01)\
				.pos(Vector2(GameConfig.FIELD_CENTER_X - 300 + i * 90, 0)).red_little_fairy()\
				.param("target_y", 360 + i * 40)\
				.param("rate", 4).param("heavy_wave", false).spawn(ctx)
		)
	for i in 7:
		tl.at(24.0 + i * 0.5).do(func():
			EnemyData.new().with_script(ENEMY01)\
				.pos(Vector2(GameConfig.FIELD_CENTER_X + 300 - i * 90, 0)).red_little_fairy()\
				.param("target_y", 200 + i * 40)\
				.param("rate", 4).param("heavy_wave", false).spawn(ctx)
			EnemyData.new().with_script(ENEMY01)\
				.pos(Vector2(GameConfig.FIELD_CENTER_X - 300 + i * 90, 0)).red_little_fairy()\
				.param("target_y", 200 + i * 40)\
				.param("rate", 4).param("heavy_wave", false).spawn(ctx)
		)

	# ── Boss ──
	var kamorui := BossData.new().name("卡摩瑞").look(BOSS_POINT).phase(NON_01)
	var boss_holder := [null]

	tl.at(35.0).do(func():
		boss_holder[0] = StageManager.spawn_boss(kamorui, Vector2(-50, 500), ctx)
		var b := boss_holder[0] as Boss
		var tw := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
		tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(b, "global_position", Vector2(GameConfig.FIELD_CENTER_X, 250), 1.5)
	)

	# 非符 1 (Timeline 冻结中，等击破)
	tl.at(38.0).phase(func(): return boss_holder[0], NON_01)
	# ← Boss 被击破后从这里继续 →
	tl.wait(2.0).do(func():
		var b := boss_holder[0] as Boss
		b.set_exit_controlled()
		b.die()
		var tw := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
		tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(b, "global_position", Vector2(GameConfig.FIELD_CENTER_X, -150), 2.0)
		tw.tween_callback(b.queue_free)
	)

	super.start(ctx, target)
