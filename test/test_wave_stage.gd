extends GutTest
## 数据关卡 WaveStage 测试 —— 同 t 多波次的并发正确性
##
## 历史 bug（2026-08 修复）：_wave_state 是成员单例，两个波次同 t 同时触发时
## 互相覆盖 → 只生成一波 + 弹幕参数错乱。修复：状态改为闭包局部。

## 测试桩：覆写 _spawn_one 记录生成的敌人（不实例化真实敌人）
class MockWaveStage:
	extends "res://data/stage_demo/wave_stage.gd"
	var spawned: Array = []

	func _spawn_one(wave: Dictionary) -> void:
		spawned.append(str(wave.get("enemy")))


var _stage: MockWaveStage


func before_each():
	_stage = MockWaveStage.new()
	add_child_autofree(_stage)


## 两个独立 state 交替步进（模拟同 t 双波次并行调度）：
## 各自计数独立、互不干扰、敌人都生成（修复前共享 _wave_state 会丢波次）
func test_wave_step_state_is_isolated():
	# 模拟同 t 两个波次的独立状态（修复后 _start_wave 内部生成闭包 state）
	var s1 := {"wave": {"enemy": "red_little"}, "remaining": 2, "interval": 0.1}
	var s2 := {"wave": {"enemy": "blue_little"}, "remaining": 3, "interval": 0.1}
	# 交替步进（等价于 runner 并行调度两个协程）
	for i in 4:
		var r1: Variant = _stage._wave_step(null, s1)
		var r2: Variant = _stage._wave_step(null, s2)
		if i < 2:
			assert_true(r1 is float, "s1 第 %d 步应仍在运行" % i)
		if i < 3:
			assert_true(r2 is float, "s2 第 %d 步应仍在运行" % i)
	assert_eq(s1.remaining, 0, "s1 应生成完 2 个")
	assert_eq(s2.remaining, 0, "s2 应生成完 3 个")
	assert_eq(_stage.spawned.size(), 5, "两波共生成 5 个（修复前共享状态会丢波次）")
	assert_eq(_stage.spawned.count("red_little"), 2, "红波 2 个")
	assert_eq(_stage.spawned.count("blue_little"), 3, "蓝波 3 个")


## 修复后的 _start_wave：不再写成员 _wave_state（该变量已删除）
func test_no_shared_member_state():
	assert_false("_wave_state" in _stage, "成员 _wave_state 应已删除（改用闭包局部状态）")


## Timeline 层同 t 事件确认：两事件都触发（证明丢波次根因在 WaveStage 状态，
## 不在 Timeline 调度）
func test_timeline_same_t_both_fire():
	var runner := CoroutineRunner.new()
	add_child_autofree(runner)
	var ctx := StageContext.new(runner)
	var tl := Timeline.new(ctx)
	var fired: Array = []
	tl.at(2.0).do(func(): fired.append("A"))
	tl.at(2.0).do(func(): fired.append("B"))
	tl.tick(2.0)
	assert_eq(fired, ["A", "B"], "同 t 两事件都应触发")


## _start_wave 启动后两个协程均被注册（run_parallel 每波次独立 Task）
func test_start_wave_registers_independent_tasks():
	_stage._start_wave({"enemy": "red_little", "count": 2, "interval": 0.1})
	_stage._start_wave({"enemy": "blue_little", "count": 3, "interval": 0.1})
	# 两波各注册一个 Task（run_parallel 追加并行任务）
	assert_eq(_stage._tasks.size(), 2, "两波应注册两个并行 Task")
	_stage.stop()
	assert_eq(_stage._tasks.size(), 0, "stop 应清空")
