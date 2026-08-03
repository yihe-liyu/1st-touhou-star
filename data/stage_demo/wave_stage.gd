## 数据驱动关卡解释器 —— 读 StageTimeline 波次表，按 t 生成敌人
## 波次 = 敌人模板（注册表）+ 参数；复用现有 EnemyData/spawn_enemy_data
extends CoroutineScript

const TIMELINE = preload("res://data/stage_demo/stage_timeline.tres")  # 默认（res:// 只读）
const USER_TIMELINE_PATH = "user://data/stage_demo/stage_timeline.tres"  # 工作台保存的可写副本


## 优先读工作台保存的 user:// 副本，否则用 res:// 默认
static func current_timeline() -> StageTimeline:
	if FileAccess.file_exists(USER_TIMELINE_PATH):
		return load(USER_TIMELINE_PATH)
	return TIMELINE

## 测试/编辑器注入用：优先返回此 timeline（否则回退 static 默认读取）
var timeline_override: StageTimeline

func _current_timeline() -> StageTimeline:
	if timeline_override:
		return timeline_override
	return current_timeline()


func start(p_ctx: StageContext, p_target: Node2D = null):
	ctx = p_ctx
	if p_target:
		target = p_target
	var tl := start_timeline()
	# 续跑起点（工作台 E3）：从目标时刻前 3 秒起跑，起点前已结束的波次跳过
	var from := StageManager.pending_start_from
	var t0 := maxf(from - 3.0, 0.0) if from >= 0.0 else 0.0
	for wave in _current_timeline().waves:
		var w: Dictionary = wave  # 循环捕获：GDScript 闭包要复制
		var wt := float(w.t)
		if from >= 0.0:
			var dur := maxf(float(w.get("count", 1)) * float(w.get("interval", 0.5)), 1.0)
			if wt + dur < t0 - 0.05:
				continue  # 起点前已完全结束的波次：跳过（跨起点的保留，启动瞬间继续生成）
		# 事件注册绝对时刻；Timeline 时钟从 t0 起步 → 自然在正确时刻触发
		tl.at(wt).do(func():
			_start_wave(w)
		)
	# 时钟从续跑起点起步：状态栏/时间轴显示绝对关卡时刻
	tl.start_at(t0)
	super.start(ctx, target)
	if t0 > 0.0:
		set_game_time(t0)  # 在 run()（会重置 _clock=0）之后设置


func _start_wave(wave: Dictionary) -> void:
	# 每波次独立状态（闭包局部，不能放成员变量）：
	# 两个波次同 t 同时触发时，成员变量会被覆盖 → 丢波次 + 弹幕参数错乱
	var state := {
		"wave": wave,
		"remaining": int(wave.get("count", 1)),
		"interval": float(wave.get("interval", 0.5)),
	}
	run_parallel(_wave_step.bind(ctx, state))


## 每帧驱动：生成一个敌人 → 等 interval → 再生成
## state 是闭包局部：多波次并行（含同 t）互不干扰
func _wave_step(_p_ctx: StageContext, state: Dictionary) -> Variant:
	if int(state.remaining) <= 0:
		return false
	_spawn_one(state.wave)
	state.remaining = int(state.remaining) - 1
	return float(state.interval)


func _spawn_one(wave: Dictionary) -> void:
	var data := EnemyTemplateRegistry.build(str(wave.get("enemy", "")))
	if data == null:
		return
	var params: Dictionary = wave.get("params", {})
	for k in params:
		data.param(k, params[k])
	# 生成位置：spawn_pos [x,y] 优先，否则 spawn_x/spawn_y，默认顶部外居中
	var sx := float(wave.get("spawn_x", GameConfig.FIELD_CENTER_X))
	var sy := float(wave.get("spawn_y", -40.0))
	if wave.has("spawn_pos"):
		var sp: Vector2 = wave.spawn_pos
		sx = sp.x
		sy = sp.y
	data.pos(Vector2(sx, sy))
	var enemy: Enemy = data.spawn(ctx)
	# 波次指定弹幕模式：追加挂弹幕驱动（敌人脚本管移动，driver 管弹幕）
	if enemy and not str(wave.get("pattern", "")).is_empty():
		_attach_pattern(enemy, wave)


## 从波次字典构造弹幕蓝图（纯函数，测试友好）
static func build_pattern_from_wave(wave: Dictionary) -> BulletPattern:
	var bp := BulletPattern.new()
	bp.pattern = str(wave.get("pattern", "ring"))
	bp.interval = float(wave.get("pattern_interval", 0.3))
	bp.params = wave.get("pattern_params", {})
	bp.bullet_params = wave.get("bullet_params", {})
	return bp


## 给敌人挂弹幕驱动（随敌人销毁；origin=self 从敌人位置发弹）
func _attach_pattern(enemy: Node, wave: Dictionary) -> void:
	if enemy == null:
		return
	var driver := PatternDriver.new()
	driver.patterns = [build_pattern_from_wave(wave)]
	enemy.add_child(driver)
	driver.start(ctx, enemy)
