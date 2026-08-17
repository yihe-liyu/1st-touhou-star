extends GutTest
## 通用击中特效类测试：一个类驱动所有特效场景（数据驱动验证）

func test_generic_class_drives_animated_scene():
	# 动画版场景（marisa 星弹）：AnimatedSprite2D + 通用脚本
	var scene: PackedScene = preload("res://scenes/effect/hit_effect_marisa.tscn")
	var probe := scene.instantiate()
	autofree(probe)
	assert_eq(probe.get_script().resource_path,
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
	var probe := scene.instantiate()
	autofree(probe)
	assert_eq(probe.get_script().resource_path,
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

func test_anim_effect_no_fade_keeps_alpha():
	# fade_time=0：动画版不淡出（alpha 保持 1），动画播完才回收
	var scene: PackedScene = preload("res://scenes/effect/hit_effect_marisa.tscn")
	var eff = scene.instantiate()
	autofree(eff)
	add_child(eff)
	eff.fade_time = 0.0  # 不淡出模式
	eff.activate(Vector2(100, 100), Vector2(0, -1), Color.WHITE)
	var anim: AnimatedSprite2D = eff.get_node("AnimatedSprite2D")
	await wait_seconds(0.1)
	assert_almost_eq(anim.modulate.a, 1.0, 0.01, "fade_time=0 时不应淡出（alpha 保持 1）")

func test_pos_jitter_default_zero():
	# 默认 pos_jitter=0：生成位置 = 命中点（不偏移）
	var scene: PackedScene = preload("res://scenes/effect/hit_effect_marisa_option01.tscn")
	var eff = scene.instantiate()
	autofree(eff)
	add_child(eff)
	assert_eq(eff.pos_jitter, 0.0, "pos_jitter 默认应为 0")
	eff.activate(Vector2(200, 300), Vector2(0, -1), Color.WHITE)
	assert_eq(eff.global_position, Vector2(200, 300), "默认不偏移（位置 = 命中点）")

func test_pos_jitter_offsets_within_range():
	var scene: PackedScene = preload("res://scenes/effect/hit_effect_marisa_option01.tscn")
	var eff = scene.instantiate()
	autofree(eff)
	add_child(eff)
	eff.pos_jitter = 10.0
	eff.activate(Vector2(200, 300), Vector2(0, -1), Color.WHITE)
	var off: Vector2 = eff.global_position - Vector2(200, 300)
	assert_lt(absf(off.x), 10.5, "x 偏移应在 ±10 内")
	assert_lt(absf(off.y), 10.5, "y 偏移应在 ±10 内")
