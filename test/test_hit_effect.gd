extends GutTest
## 通用击中特效类测试：一个类驱动所有特效场景（数据驱动验证）

func test_generic_class_drives_animated_scene():
	# 动画版场景（marisa 星弹）：AnimatedSprite2D + 通用脚本
	var scene: PackedScene = preload("res://scenes/effect/hit_effect_marisa.tscn")
	assert_eq(scene.instantiate().get_script().resource_path,
		"res://scripts/effect/player_bullet_hit_effect.gd", "动画版应挂通用类")
	var eff = scene.instantiate()
	autofree(eff)
	add_child(eff)
	eff.activate(Vector2(100, 100), Vector2(0, -1), Color.WHITE)
	assert_not_null(eff.get_node_or_null("AnimatedSprite2D"), "应有 AnimatedSprite2D")
	assert_true(eff.visible, "激活后应可见")

func test_generic_class_drives_sprite_scene():
	# 单帧版场景（魔理沙激光星爆）：Sprite2D + 参数（speed 750 / fade 0.2 / jitter 0.1）
	var scene: PackedScene = preload("res://scenes/effect/hit_effect_marisa_option01.tscn")
	assert_eq(scene.instantiate().get_script().resource_path,
		"res://scripts/effect/player_bullet_hit_effect.gd", "单帧版应挂通用类")
	var eff = scene.instantiate()
	autofree(eff)
	add_child(eff)
	assert_almost_eq(eff.speed, 750.0, 0.01, "单帧版 speed 参数应为 750（数据驱动）")
	assert_almost_eq(eff.fade_time, 0.2, 0.01, "单帧版 fade_time 参数应为 0.2")
	assert_almost_eq(eff.jitter, 0.1, 0.01, "单帧版 jitter 参数应为 0.1")

func test_sprite_effect_fades_out():
	var scene: PackedScene = preload("res://scenes/effect/hit_effect_marisa_option01.tscn")
	var eff = scene.instantiate()
	autofree(eff)
	add_child(eff)
	eff.activate(Vector2(100, 100), Vector2(0, -1), Color.WHITE)
	await wait_seconds(0.35)
	assert_false(is_instance_valid(eff), "淡出后应回收（实例已释放）")
