extends GutTest
## Boss 位置指示器回归测试：生成/跟随 x/对齐框底/随 Boss 销毁

func test_boss_indicator_follows_boss():
	var boss = load("res://scripts/enemy/boss.gd").new()
	add_child(boss)
	boss.start_boss()

	var indicator: Sprite2D = boss._pos_indicator
	assert_not_null(indicator, "start_boss 后应创建指示器")
	if indicator == null:
		return

	# x 跟随 Boss（y 固定）
	boss.global_position = Vector2(300, 150)
	boss._process(0.016)
	assert_eq(indicator.global_position.x, 300.0, "指示器 x 应跟随 Boss")

	# y 对齐游戏框底（贴图下边缘贴底线）
	var expected_y: float = GameConfig.FIELD_BOTTOM - indicator.texture.get_height() / 2.0
	assert_eq(indicator.global_position.y, expected_y, "指示器 y 应对齐游戏框底")

	# Boss 移动后指示器 x 继续跟随
	boss.global_position = Vector2(600, 400)
	boss._process(0.016)
	assert_eq(indicator.global_position.x, 600.0, "指示器 x 应持续跟随 Boss")
	assert_eq(indicator.global_position.y, expected_y, "指示器 y 应保持不变")

	# Boss 销毁 → 指示器删除
	boss.queue_free()
	await wait_physics_frames(2)
	assert_false(is_instance_valid(indicator), "Boss 销毁后指示器应被删除")
