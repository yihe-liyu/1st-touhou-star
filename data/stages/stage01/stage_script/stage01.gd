extends CoroutineScript
## 第一面——新的 Timeline API

const ENEMY01 = preload("res://data/stages/stage01/enemy/enemy01.gd")
const ENEMY02 = preload("res://data/stages/stage01/enemy/enemy02.gd")
const ENEMY03 = preload("res://data/stages/stage01/enemy/enemy03.gd")
const ENEMY04 = preload("res://data/stages/stage01/enemy/enemy04.gd")

const FLY_AWAY = preload("res://data/stages/stage01/enemy/fly_away.gd")

const DIALOGUE01 = preload("res://data/dialogue/reimu/stage01_before.tres")

const BOSS_POINT = preload("res://data/enemy_visual/boss/stage01/kamorui.tscn")

const NON_MID01 = preload("res://data/stages/stage01/phase/non_mid01/non_mid01.tres")
const NON01 = preload("res://data/stages/stage01/phase/non01/non01.tres")
#const SPELL01 = [preload("res://data/stages/stage01/phase/spell01/spell001.tres"),\
				 #preload("res://data/stages/stage01/phase/spell01/spell002.tres"),\
				 #preload("res://data/stages/stage01/phase/spell01/spell003.tres"),\
				 #preload("res://data/stages/stage01/phase/spell01/spell004.tres")]

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
	var kamorui := BossData.new().name("卡摩瑞").look(BOSS_POINT).phase(NON_MID01)#.phase(diff_pick(SPELL03))
	var boss_holder := [null]

	tl.at(35.0).do(func():
		boss_holder[0] = StageManager.spawn_boss(kamorui, Vector2(-50, 500), ctx)
		var b := boss_holder[0] as Boss
		var tw := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
		tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(b, "global_position", Vector2(GameConfig.FIELD_CENTER_X, 250), 1.5)
	)

	# 非符 1
	tl.at(38.0).start_phase(func(): return boss_holder[0], NON_MID01)
	# ← 非符 被击破后 1s → 符卡（phase 继承 wait 偏移，击破后激活）
	#tl.wait(1.0).start_phase(func(): return boss_holder[0], diff_pick(SPELL03))
	# ← 符卡被击破后 2s → 退场
	tl.wait(2.0).do(func():
		var b := boss_holder[0] as Boss
		b.set_exit_controlled()
		b.die()
		var tw := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
		tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(b, "global_position", Vector2(GameConfig.FIELD_CENTER_X, -150), 2.0)
		tw.tween_callback(b.queue_free)
	)

	# Boss 后增援波次（设计：提前击破 Boss → 固定时刻增援趁 Boss 已死触发，
	# 打得快增援多、打得慢被 if 吞掉 —— 内容/资源节奏由玩家速度决定）
	for i in 9:
		tl.at(52.0 + i).do(func():
			if GameState.get_boss() == null:
				_spawn_mid_enemy(0, i, true)
		)
	for i in 7:
		tl.at(54.5 + i).do(func():
			if GameState.get_boss() == null:
				_spawn_mid_enemy(1, i, true)
		)
		
	for i in 18:
		tl.at(63.0 + i * 0.7).do(func():
			_spawn_mid_enemy(0, i, false, 1)
		)
	for i in 18:
		tl.at(63.3 + i * 0.7).do(func():
			_spawn_mid_enemy(1, i, false, 1)
		)
	
	tl.at(60.0).do(func():
		EnemyData.new().blue_big_fairy() \
			.with_script(ENEMY04) \
			.pos(Vector2(GameConfig.FIELD_CENTER_X - 64, -32)) \
			.hp(500) \
			.spawn(ctx)
	)
	tl.at(68.5).do(func():
		EnemyData.new().blue_big_fairy() \
			.with_script(ENEMY04) \
			.pos(Vector2(GameConfig.FIELD_CENTER_X + 64, -32)) \
			.hp(600) \
			.spawn(ctx)
	)
	tl.at(77.0).do(func():
		EnemyData.new().blue_big_fairy() \
			.with_script(ENEMY04) \
			.pos(Vector2(GameConfig.FIELD_CENTER_X - 192, -32)) \
			.hp(500) \
			.spawn(ctx)
		EnemyData.new().blue_big_fairy() \
			.with_script(ENEMY04) \
			.pos(Vector2(GameConfig.FIELD_CENTER_X + 192, -32)) \
			.hp(600) \
			.spawn(ctx)
	)
	
	for i in 18:
		tl.at(80.0 + i * 0.3).do(func():
			_spawn_mid_enemy(0, i, false, 1)
		)
	for i in 18:
		tl.at(80.0 + i * 0.3).do(func():
			_spawn_mid_enemy(1, i, false, 1)
		)

	super.start(ctx, target)


## Boss 后横穿增援：side 0=右→左，1=左→右（i 决定颜色/位置随机偏移）
func _spawn_mid_enemy(side: int, i: int, heavy_wave: bool, start_time: float = 2.0) -> void:
	var from_right := side == 0
	var x: float = GameConfig.FIELD_RIGHT + 50 if from_right else GameConfig.FIELD_LEFT - 50
	var tx: float = GameConfig.FIELD_LEFT + 175 if from_right else GameConfig.FIELD_RIGHT - 175
	var y: float = 431
	var off: int = RNG.randi() % 200 - 100
	var e := EnemyData.new()
	if i % 2:
		e.red_little_fairy()
	else:
		e.blue_little_fairy()
	if !heavy_wave:
		e.param("rate", 4)
	e.with_script(ENEMY03) \
		.pos(Vector2(x, y + off - 175)) \
		.param("target_pos", Vector2(tx + off, y + off)) \
		.param("bullet_color", Color.RED if i % 2 else Color.BLUE) \
		.param("heavy_wave", heavy_wave) \
		.param("start_time", start_time) \
		.spawn(ctx)
