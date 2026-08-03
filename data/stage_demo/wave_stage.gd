## 数据驱动关卡解释器 —— 读 StageTimeline 波次表，按 t 生成敌人
## 波次 = 敌人模板（注册表）+ 参数；复用现有 EnemyData/spawn_enemy_data
extends CoroutineScript

const TIMELINE = preload("res://data/stage_demo/stage_timeline.tres")  # 默认（res:// 只读）
const USER_TIMELINE_PATH = "user://data/stage_demo/stage_timeline.tres"  # 工作台保存的可写副本


## 优先读工作台保存的 user:// 副本，否则用 res:// 默认
## 数据关卡优先用 StageData.timeline（各关卡自己的编排数据）
static func current_timeline() -> StageTimeline:
	var stage := StageManager.current_stage
	if stage and stage.timeline:
		var user_p := "user://" + stage.timeline.resource_path.trim_prefix("res://")
		if FileAccess.file_exists(user_p):
			return load(user_p)
		return stage.timeline
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
	# 演出事件（音乐/对话/自定义演出脚本）
	for ev in _current_timeline().events:
		var e: Dictionary = ev
		var et := float(e.get("t", 0.0))
		var etype := str(e.get("type", ""))
		tl.at(et).do(func():
			_run_event(e, etype)
		)	# 数据关卡的 Boss（StageData.boss）：到 boss_time 生成 + 依次启动阶段
	var stage_data: StageData = StageManager.current_stage
	if stage_data and stage_data.boss and stage_data.boss.phases.size() > 0:
		var boss_data: BossData = stage_data.boss
		var boss_t := stage_data.boss_time
		tl.at(boss_t).do(func():
			_spawn_and_run_boss(boss_data)
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
	var data := _build_enemy(wave)
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
	data.spawn(ctx)


## 敌人构建：有 behavior 字段 → 数据预设 × 行为自由组合；
## 只有 enemy 字段（旧数据）→ 当模板名构建（兼容）
func _build_enemy(wave: Dictionary) -> EnemyData:
	var enemy_name := str(wave.get("enemy", ""))
	var behavior := str(wave.get("behavior", ""))
	if not behavior.is_empty():
		return EnemyTemplateRegistry.build_from(enemy_name, behavior)
	return EnemyTemplateRegistry.build(enemy_name)


# ═══ Boss 阶段驱动（数据关卡）═══

## 生成 Boss + 入场（自定义脚本或默认顶部飞入）+ 依次启动阶段
func _spawn_and_run_boss(boss_data: BossData) -> void:
	var boss: Boss = StageManager.spawn_boss(boss_data, Vector2(GameConfig.FIELD_CENTER_X, -60), ctx)
	if boss == null:
		return
	if boss_data.enter_script:
		var enter: CoroutineScript = boss_data.enter_script.new()
		boss.add_child(enter)
		enter.start(ctx, boss)
	else:
		# 默认入场：顶部飞入
		var tw := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
		tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(boss, "global_position", Vector2(GameConfig.FIELD_CENTER_X, 200), 1.5)
	run_phase(boss, boss_data, 0)


## 启动阶段：冻结关卡时间直到击破，然后下一阶段；全部打完退场
func run_phase(boss: Boss, boss_data: BossData, idx: int) -> void:
	if idx >= boss_data.phases.size():
		# 全部击破：自定义退场脚本或默认
		if boss_data.exit_script:
			var exit: CoroutineScript = boss_data.exit_script.new()
			boss.add_child(exit)
			exit.start(ctx, boss)
		else:
			boss.set_exit_controlled()
			boss.die()
		return
	var phase: PhaseData = boss_data.phases[idx]
	if _tl:
		_tl.pause()  # 阶段期间冻结关卡编排（Boss 战专属）
	boss.start_phase(phase)
	boss.phase_cleared.connect(func(_captured: bool, _bonus: int):
		if _tl:
			_tl.resume()
		run_phase(boss, boss_data, idx + 1)
	, CONNECT_ONE_SHOT)


## 演出事件执行（bgm/dialogue/custom 脚本逃逸口）
func _run_event(ev: Dictionary, etype: String) -> void:
	match etype:
		"bgm":
			var bgm: AudioStream = AssetRegistry.get_bgm(str(ev.get("bgm", "")))
			if bgm:
				ctx.audio.play_bgm(bgm)
		"dialogue":
			var path := str(ev.get("dialogue", ""))
			if not path.is_empty() and ResourceLoader.exists(path):
				var data: Resource = load(path)
				if data and data.get("lines") != null:
					ctx.play_dialogue(data.get("lines"))
		"custom":
			var spath := str(ev.get("script", ""))
			if not spath.is_empty() and ResourceLoader.exists(spath):
				var scr: Script = load(spath)
				if scr and scr.new() is CoroutineScript:
					var inst: CoroutineScript = scr.new()
					add_child(inst)
					inst.start(ctx)
