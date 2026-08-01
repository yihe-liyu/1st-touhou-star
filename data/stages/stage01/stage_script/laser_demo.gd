extends CoroutineScript
## 激光示例关卡 —— 展示 Laser 2.0（新引擎 + 形态预设）
## 所有坐标尊重东方的框数据：左64 右832 上32 下928

func start(p_ctx: StageContext, _p_target: Node2D = null):
	ctx = p_ctx
	var tl := start_timeline()

	tl.at(0.0).do(func(): ctx.audio.play_bgm(AssetRegistry.get_bgm("stage1")))

	# ① 红色直线（瞬间全开）：从左边框到右边框
	tl.at(0.5).do(func():
		ctx.bullets.fire_line_laser(Vector2(GameConfig.FIELD_LEFT, 400), Vector2(GameConfig.FIELD_RIGHT, 400), Color(1.0, 0.2, 0.15), 10.0)
	)

	# ② 蓝色生长型 S 形（手写曲线）：穿梭整个可移动区域
	tl.at(2.0).do(func():
		var curve := Curve2D.new()
		curve.add_point(Vector2(200, 32))
		curve.add_point(Vector2(700, 200))
		curve.add_point(Vector2(200, 480))
		curve.add_point(Vector2(700, 700))
		curve.add_point(Vector2(200, GameConfig.FIELD_BOTTOM))
		ctx.bullets.fire_growing_laser(curve, Color(0.2, 0.6, 1.0), 800.0, 500.0, 12.0)
	)

	# ③ 绿色正弦波预设（瞬间全开）：横向游动
	tl.at(4.0).do(func():
		var sk := LaserPresets.wave(
			Vector2(GameConfig.FIELD_LEFT, 550), Vector2(1, 0),
			768.0, 90.0, 192.0)
		ctx.bullets.spawn_laser(sk, Color(0.2, 1.0, 0.5), {"grow": false, "lifetime": 10.0, "core_width": 16.0})
	)

	# ④ 橙色螺旋预设（生长型）：从中心螺旋展开
	tl.at(6.0).do(func():
		var sk := LaserPresets.spiral(
			Vector2(GameConfig.FIELD_CENTER_X, 480), 320.0, 1.6, 0.0)
		ctx.bullets.spawn_laser(sk, Color(1.0, 0.6, 0.2), {"grow": true, "grow_speed": 500.0, "tail": 240.0, "lifetime": 12.0, "core_width": 14.0})
	)

	# ⑤ 青色扇形扫预设（瞬间全开）：从上往下扫
	tl.at(8.0).do(func():
		var sk := LaserPresets.sweep(
			Vector2(GameConfig.FIELD_CENTER_X, 300), Vector2(0, 1),
			PI * 0.5, 420.0, 24)
		ctx.bullets.spawn_laser(sk, Color(0.3, 0.9, 1.0), {"grow": false, "lifetime": 10.0, "core_width": 16.0})
	)

	# ⑥ 黄色自机导向：从左边框射向玩家（每 2 秒）
	tl.at(3.0).every(2.0).do(func():
		ctx.bullets.fire_homing_laser(
			Vector2(64, 480), ctx.player.get_position(),
			Color(1.0, 0.8, 0.0), 80.0, 600.0, 8.0
		)
	)

	super.start(ctx)
