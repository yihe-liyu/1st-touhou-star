extends GutTest
## PatternRegistry / BulletPattern / PatternDriver 测试（E5 弹幕蓝图）
##
## 覆盖：注册表元数据、难度数组取值、脚本接入接口（PatternScript）、
##       弹丸构造、原点解析、蓝图校验

## 脚本模式测试桩：展示"接脚本的接口"（extends PatternScript + 覆写 _tick + 注册）
class MockPatternScript:
	extends "res://scripts/data/pattern_script.gd"
	var fired: Array = []

	func _tick(_ctx: StageContext) -> Variant:
		fired.append(pattern_params().get("tag", "?"))
		return pattern_interval()


var _runner: CoroutineRunner
var _ctx: StageContext


func before_each():
	_runner = CoroutineRunner.new()
	add_child_autofree(_runner)
	_ctx = StageContext.new(_runner)
	PatternRegistry.register_script("mock_test", MockPatternScript)


func after_each():
	PatternRegistry.unregister_script("mock_test")


## 注册表：内置 + 注册脚本合并；is_script 区分
func test_registry_names_and_kinds():
	var names := PatternRegistry.names()
	assert_true(names.has("ring"), "内置 ring 应存在")
	assert_true(names.has("aim"), "内置 aim 应存在")
	assert_true(names.has("fan"), "内置 fan 应存在")
	assert_true(names.has("mock_test"), "注册脚本应出现在下拉框")
	assert_false(PatternRegistry.is_script("ring"), "内置不是脚本")
	assert_true(PatternRegistry.is_script("mock_test"), "注册的是脚本")
	assert_true(PatternRegistry.has("ring"))


## 脚本接口：instantiate 出 PatternScript 实例，config 注入后参数可读
func test_script_interface_instantiate():
	var inst := PatternRegistry.instantiate_script("mock_test")
	assert_not_null(inst, "应能实例化注册脚本")
	assert_true(inst is CoroutineScript, "实例应为 CoroutineScript")
	var bp := BulletPattern.new()
	bp.pattern = "mock_test"
	bp.interval = 0.5
	bp.params = {"tag": "hello"}
	inst.config = bp
	var mock := inst as MockPatternScript
	assert_eq(mock.pattern_params().get("tag", ""), "hello", "config 注入后 pattern_params 可读")
	assert_almost_eq(mock.pattern_interval(), 0.5, 0.001, "interval 可读")


## 难度数组取值：数组按难度取，标量原样
func test_diff_pick():
	GameState.selected_difficulty = 0
	assert_eq(PatternRegistry.diff_pick([10, 20, 30, 40]), 10, "Easy 取 10")
	GameState.selected_difficulty = 3
	assert_eq(PatternRegistry.diff_pick([10, 20, 30, 40]), 40, "Lunatic 取 40")
	assert_eq(PatternRegistry.diff_pick(25), 25, "标量原样")
	GameState.selected_difficulty = 1


## 弹丸构造：bullet_params → BulletData（enemy/blend/tex/speed/color）
func test_build_bullet():
	var bp := BulletPattern.new()
	bp.bullet_params = {"tex": "小玉", "speed": 300.0, "color": Color.RED, "blend": true}
	var data := PatternDriver.build_bullet(bp)
	assert_not_null(data)
	assert_eq(data.faction, BulletData.Faction.ENEMY, "默认敌弹")
	assert_almost_eq(data.velocity.y, 300.0, 0.001, "speed 生效")
	assert_eq(data.tint, Color.RED, "color 生效")
	assert_eq(data.tint_mode, BulletData.TintMode.BLEND, "blend 生效")
	assert_not_null(data.texture, "tex 应从 AssetRegistry 查到贴图")


## 原点解析：self / pos / edge
func test_resolve_origin():
	var bp := BulletPattern.new()
	# self = 挂载者位置
	var host := Node2D.new()
	add_child_autofree(host)
	host.global_position = Vector2(100, 200)
	bp.origin = "self"
	assert_eq(PatternDriver.resolve_origin(_ctx, host, bp), Vector2(100, 200), "self 用挂载者位置")
	# pos = 固定坐标
	bp.origin = "pos"
	bp.origin_pos = Vector2(400, 100)
	assert_eq(PatternDriver.resolve_origin(_ctx, host, bp), Vector2(400, 100), "pos 用固定坐标")
	# edge = 屏幕边（top）
	bp.origin = "edge"
	bp.origin_side = "top"
	assert_eq(PatternDriver.resolve_origin(_ctx, host, bp),
		Vector2(GameConfig.FIELD_CENTER_X, GameConfig.FIELD_TOP - 24.0), "edge top 在框外上方")


## 蓝图校验：interval <= 0 报错
func test_bullet_pattern_validate():
	var bad := BulletPattern.new()
	bad.pattern = "ring"
	bad.interval = 0.0
	assert_gt(bad.validate().size(), 0, "interval=0 应报错")
	var good := BulletPattern.new()
	assert_eq(good.validate().size(), 0, "默认合法")


## 建议参数（Dictionary schema）：内置模式写死
func test_suggest_params_builtin():
	var ring: Dictionary = PatternRegistry.suggest_params("ring")
	assert_true(ring.has("n") and ring.has("speed") and ring.has("aim"), "ring 建议含 n/speed/aim")
	assert_eq(ring.get("n"), 24, "默认 n=24")
	assert_true(ring.get("aim") == false, "默认 aim=false")


## 建议参数：脚本模式优先 params_schema()（作者声明）
func test_suggest_params_script_schema():
	var spiral: Dictionary = PatternRegistry.suggest_params("spiral")
	assert_true(spiral.has("arms") and spiral.has("step") and spiral.has("speed"),
		"spiral 建议来自 params_schema：arms/step/speed")
	assert_eq(spiral.get("arms"), 2, "默认 arms=2")


## 建议参数：无 params_schema 的脚本 → 反射脚本变量（排除私有/基类）
func test_suggest_params_script_reflect():
	var mock: Dictionary = PatternRegistry.suggest_params("mock_test")
	assert_true(mock.has("fired"), "应反射出 MockPatternScript.fired")
	assert_false(mock.has("ctx"), "不应包含基类 ctx")
	assert_false(mock.has("target"), "不应包含基类 target")


## 敌人模板建议：defaults 优先 + 反射脚本变量补全
func test_enemy_template_suggest():
	var tpl: Dictionary = EnemyTemplateRegistry.suggest_params("red_little")
	assert_true(tpl.has("target_y"), "defaults 的 target_y 应在")
	assert_almost_eq(float(tpl.get("target_y")), 300.0, 0.001, "target_y 默认 300")
	assert_true(tpl.has("heavy_wave"), "反射出 enemy01 的 heavy_wave")
	assert_true(tpl.has("rate"), "反射出 enemy01 的 rate")
	assert_false(tpl.has("ctx"), "不应包含基类 ctx")
	assert_false(tpl.has("_tl"), "不应包含私有 _tl")


## 数据/行为分离：同数据换行为（外观血量判定相同、脚本不同）；同行为换数据
## 用 build_from 直接组合（模板只是旧数据兼容层，新内容不造模板）
func test_template_data_behavior_separation():
	var a := EnemyTemplateRegistry.build("red_little")
	# 同数据换行为：red_little_fairy × aim_scatter vs red_little_fairy × sway_aim
	var b := EnemyTemplateRegistry.build_from("red_little_fairy", "sway_aim")
	assert_not_null(a, "red_little 应构建")
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


## 数据/行为自由组合：build_from 任意搭配 + 预设反射
func test_build_from_free_combine():
	var a := EnemyTemplateRegistry.build_from("red_little_fairy", "sway_aim")
	assert_not_null(a, "红小妖精数据 × 摆荡行为 应构建")
	assert_eq(a.max_hp, 45, "数据层生效：45 血")
	assert_eq(a.hitbox_radius, 25, "数据层生效：25 判定")
	assert_eq(a.get_enemy_script(), preload("res://scripts/data/enemy_templates/sway_fairy.gd"),
		"行为层生效：sway_fairy 脚本")
	# 数据预设反射（新增预设自动出现）
	var names := EnemyTemplateRegistry.data_names()
	assert_true(names.has("red_little_fairy"), "预设应被反射出来")
	assert_true(names.has("purple_YY_jade"), "jade 预设也在")
	assert_false(names.has("build"), "不应包含普通方法")
	# 行为名列表
	assert_true(EnemyTemplateRegistry.behavior_names().has("sway_aim"), "行为名列表")
	# 未知组合防护
	var bad := EnemyTemplateRegistry.build_from("not_a_preset", "sway_aim")
	assert_null(bad, "未知数据预设应返回 null")


## .tres 数据预设：目录读取 + 加载（script 字段正确序列化）
func test_tres_presets():
	var names := EnemyTemplateRegistry.data_names()
	assert_true(names.has("red_little_fairy"), ".tres 预设应从目录读出")
	assert_true(names.has("purple_YY_jade"), "jade 预设也在目录")
	# 加载 .tres 预设
	var data := EnemyTemplateRegistry._load_preset("red_little_fairy")
	assert_not_null(data)
	assert_eq(data.max_hp, 45, "预设血量 45")
	assert_eq(data.hitbox_radius, 25, "预设判定 25")
	assert_not_null(data.visual_scene, "外观场景已序列化")
	assert_eq(data.get_script(), preload("res://scripts/data/enemy_data.gd"),
		"script 字段应为 EnemyData 脚本（修复 Callable bug 后）")
