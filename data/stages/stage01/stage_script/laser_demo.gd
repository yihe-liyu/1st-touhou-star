extends CoroutineScript
## 激光示例关卡 —— 展示三种激光的用法
## 所有坐标尊重东方的框数据：左64 右832 上32 下928

func start(p_ctx: StageContext, _p_target: Node2D = null):
	ctx = p_ctx
	var tl := start_timeline()

	tl.at(0.0).do(func(): ctx.audio.play_bgm(preload("res://assets/Music/THq01_02.夜间漫步.mp3")))

	# ① 水平红线：从左边框到右边框，y=400（可移动区域正中偏上）
	tl.at(0.5).do(func():
		ctx.bullets.fire_line_laser(Vector2(GameConfig.FIELD_LEFT, 400), Vector2(GameConfig.FIELD_RIGHT, 400), Color(1.0, 0.0, 0.0, 1.0), 10.0)
	)

	# ② 蓝色生长型 S 形：在可移动区域内来回穿梭
	tl.at(2.0).do(func():
		var curve := Curve2D.new()
		curve.add_point(Vector2(200, 32))
		curve.add_point(Vector2(700, 200))
		curve.add_point(Vector2(200, 480))
		curve.add_point(Vector2(700, 700))
		curve.add_point(Vector2(200, GameConfig.FIELD_BOTTOM))
		ctx.bullets.fire_growing_laser(curve, Color(0.2, 0.6, 1.0), 800.0, 500.0, 12.0)
	)

	# ③ 绿色固定弧形：从左下到右上
	tl.at(4.0).do(func():
		var curve := Curve2D.new()
		curve.add_point(Vector2(100, 700))
		curve.add_point(Vector2(GameConfig.FIELD_CENTER_X, GameConfig.FIELD_CENTER_Y))
		curve.add_point(Vector2(800, 300))
		ctx.bullets.fire_fixed_laser(curve, Color(0.0, 1.0, 0.3), 10.0)
	)

	# ④ 黄色自机导向：从左边框射向玩家
	tl.at(3.0).every(2.0).do(func():
		ctx.bullets.fire_homing_laser(
			Vector2(64, 480), ctx.player.get_position(),
			Color(1.0, 0.8, 0.0), 80.0, 600.0, 8.0
		)
	)

	super.start(ctx)
