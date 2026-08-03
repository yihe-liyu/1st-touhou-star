extends GutTest
## 敌人数据/行为注册表测试（EnemyTemplateRegistry）
##
## 覆盖：数据+行为自由组合、.tres 预设、参数建议（反射）


## 数据/行为分离：同数据换行为（外观血量判定相同、脚本不同）；同行为换数据
func test_data_behavior_separation():
	var a := EnemyTemplateRegistry.build_from("red_little_fairy", "aim_scatter")
	# 同数据换行为：red_little_fairy × sway_aim
	var b := EnemyTemplateRegistry.build_from("red_little_fairy", "sway_aim")
	assert_not_null(a, "build_from 应构建")
	assert_not_null(b, "build_from 应构建")
	# 同数据：外观/血量/判定相同
	assert_eq(a.visual_scene, b.visual_scene, "同数据：外观相同")
	assert_eq(a.max_hp, b.max_hp, "同数据：血量相同")
	assert_eq(a.hitbox_radius, b.hitbox_radius, "同数据：判定相同")
	# 不同行为：脚本不同
	assert_ne(a.get_enemy_script(), b.get_enemy_script(), "换行为：脚本不同")
	# 同行为换数据：外观不同、脚本相同（blue_middle_fairy × aim_scatter）
	var c := EnemyTemplateRegistry.build_from("blue_middle_fairy", "aim_scatter")
	assert_ne(c.visual_scene, a.visual_scene, "换数据：外观不同")
	assert_eq(c.get_enemy_script(), a.get_enemy_script(), "同行为：脚本相同")
	# 默认参数来自行为层 defaults
	assert_almost_eq(float(a.get_params().get("target_y")), 300.0, 0.001, "默认参数来自行为")
	assert_almost_eq(float(b.get_params().get("sway")), 80.0, 0.001, "sway 行为默认参数")


## 数据/行为自由组合 + 预设反射 + 未知防护
func test_build_from_free_combine():
	var a := EnemyTemplateRegistry.build_from("red_little_fairy", "sway_aim")
	assert_not_null(a, "红小妖精数据 × 摆荡行为 应构建")
	assert_eq(a.max_hp, 45, "数据层生效：45 血")
	assert_eq(a.get_enemy_script(), preload("res://scripts/data/enemy_templates/sway_fairy.gd"),
		"行为层生效：sway_fairy 脚本")
	# 数据预设列表（读目录）
	var names := EnemyTemplateRegistry.data_names()
	assert_true(names.has("red_little_fairy"), "预设应列出")
	assert_true(names.has("purple_YY_jade"), "jade 预设也在")
	# 行为名列表
	assert_true(EnemyTemplateRegistry.behavior_names().has("sway_aim"), "行为名列表")
	# 未知防护
	var bad := EnemyTemplateRegistry.build_from("not_a_preset", "sway_aim")
	assert_null(bad, "未知数据预设应返回 null")


## .tres 数据预设：目录读取 + 加载（script 字段正确序列化）
func test_tres_presets():
	var names := EnemyTemplateRegistry.data_names()
	assert_true(names.has("red_little_fairy"), ".tres 预设应从目录读出")
	# 加载 .tres 预设
	var data := EnemyTemplateRegistry._load_preset("red_little_fairy")
	assert_not_null(data)
	assert_eq(data.max_hp, 45, "预设血量 45")
	assert_eq(data.hitbox_radius, 25, "预设判定 25")
	assert_not_null(data.visual_scene, "外观场景已序列化")
	assert_eq(data.get_script(), preload("res://scripts/data/enemy_data.gd"),
		"script 字段应为 EnemyData 脚本（修复 Callable bug 后）")


## 行为参数建议：defaults 优先 + 反射脚本变量补全
func test_behavior_suggest():
	var tpl: Dictionary = EnemyTemplateRegistry.suggest_params("aim_scatter")
	assert_true(tpl.has("target_y"), "defaults 的 target_y 应在")
	assert_almost_eq(float(tpl.get("target_y")), 300.0, 0.001, "target_y 默认 300")
	assert_true(tpl.has("heavy_wave"), "反射出 enemy01 的 heavy_wave")
	assert_true(tpl.has("rate"), "反射出 enemy01 的 rate")
	assert_false(tpl.has("ctx"), "不应包含基类 ctx")
	assert_false(tpl.has("_tl"), "不应包含私有 _tl")
