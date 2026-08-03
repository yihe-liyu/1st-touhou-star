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
