class_name PatternDriver
extends CoroutineScript
## 弹幕蓝图驱动 —— 解释 BulletPattern 数组（PhaseData.patterns / 敌人模板）发射弹幕
##
## 每个 pattern 一个独立任务（闭包状态，同 t 多 pattern 互不干扰）：
##   - 内置模式（ring/aim/fan）：按 interval/repeats 循环 execute
##   - 脚本模式（自定义 PatternScript）：实例化并行运行
## start_delay 延迟启动；duration 到时停止；rotate_step 累计旋转（转环）
##
## 用法（Boss.start_phase 已接入）：
##   var driver := PatternDriver.new()
##   driver.patterns = data.patterns
##   add_child(driver)
##   driver.start(ctx, target)

var patterns: Array = []           # Array[BulletPattern]


## 覆写 start：必须等 super.start（run() 会 stop() 清空任务）之后注册蓝图任务
func start(p_ctx: StageContext, p_target: Node2D = null):
	ctx = p_ctx
	if p_target:
		target = p_target
	super.start(ctx, target)
	if patterns.is_empty():
		return
	for p in patterns:
		var bp := p as BulletPattern
		if bp == null:
			continue
		if bp.start_delay > 0.0:
			run_parallel(_delayed_start.bind(ctx, bp))
		else:
			_start_pattern(bp)


# ═══ 任务 ═══

## 延迟启动：等待 start_delay 后真正启动
func _delayed_start(_ctx: StageContext, bp: BulletPattern) -> Variant:
	if bp.start_delay > 0.0:
		return bp.start_delay
	_start_pattern(bp)
	return false


func _start_pattern(bp: BulletPattern) -> void:
	if PatternRegistry.is_script(bp.pattern):
		var inst := PatternRegistry.instantiate_script(bp.pattern)
		if inst == null:
			return
		inst.config = bp
		add_child(inst)
		inst.start(ctx, target)
	else:
		# 内置模式：循环任务（闭包状态：elapsed 计时 / count 计数 / rotation 累计）
		var state := {"elapsed": 0.0, "count": 0, "rotation": 0.0}
		run_parallel(func() -> Variant:
			return _loop_step(ctx, bp, state)
		)


## 内置模式单步：到 duration/repeats 上限则结束，否则发射一次
func _loop_step(_ctx: StageContext, bp: BulletPattern, state: Dictionary) -> Variant:
	if _expired(bp, state):
		return false
	_fire(bp, state)
	state.elapsed += bp.interval
	state.count += 1
	return bp.interval


func _expired(bp: BulletPattern, state: Dictionary) -> bool:
	if bp.duration > 0.0 and float(state.elapsed) >= bp.duration:
		return true
	if bp.repeats >= 0 and int(state.count) >= bp.repeats:
		return true
	return false


## 发射一次：解析原点/基准方向 → 构造弹丸 → 交给注册表执行
func _fire(bp: BulletPattern, state: Dictionary) -> void:
	var at := resolve_origin(ctx, target, bp)
	# 基准方向：首次可随机初始角（random_start），之后按 rotation 累计（rotate_step 转环）
	var base := Vector2.DOWN
	if bool(bp.params.get("random_start", false)) and int(state.count) == 0:
		base = Vector2.DOWN.rotated(RNG.randf() * TAU)
	else:
		base = Vector2.DOWN.rotated(float(state.rotation))
	var bullet := build_bullet(bp)
	if bullet == null:
		return
	PatternRegistry.execute(ctx, bp.pattern, bullet, at, base, bp.params)
	if bp.rotate_step != 0.0:
		state.rotation += deg_to_rad(bp.rotate_step)


# ═══ 静态工具（PatternScript 复用）═══

## 发射原点解析：self=挂载者 / player=玩家 / pos=固定坐标 / edge=屏幕边
static func resolve_origin(p_ctx: StageContext, host: Node2D, bp: BulletPattern) -> Vector2:
	match bp.origin:
		"player":
			if p_ctx and p_ctx.player:
				var pl := p_ctx.player.get_player()
				if is_instance_valid(pl):
					return pl.global_position
			return Vector2.ZERO
		"pos":
			return bp.origin_pos
		"edge":
			match bp.origin_side:
				"left":
					return Vector2(GameConfig.FIELD_LEFT - 24.0, GameConfig.FIELD_CENTER_Y)
				"right":
					return Vector2(GameConfig.FIELD_RIGHT + 24.0, GameConfig.FIELD_CENTER_Y)
				"bottom":
					return Vector2(GameConfig.FIELD_CENTER_X, GameConfig.FIELD_BOTTOM + 24.0)
				_:
					return Vector2(GameConfig.FIELD_CENTER_X, GameConfig.FIELD_TOP - 24.0)
		_:  # self
			return host.global_position if is_instance_valid(host) else Vector2.ZERO


## 从 BulletPattern.bullet_params 构造 BulletData（全数据驱动，无需代码）
static func build_bullet(bp: BulletPattern) -> BulletData:
	if bp == null:
		return null
	var p: Dictionary = bp.bullet_params
	if p.is_empty():
		return null
	var data := BulletData.new().enemy().blend(bool(p.get("blend", true)))
	if p.has("tex"):
		data.tex(str(p.get("tex")))
	if p.has("speed"):
		data.speed(float(p.get("speed")))
	if p.has("color"):
		data.color(p.get("color"))
	if p.has("dir"):
		var d: Vector2 = p.get("dir")
		data.dir(d.x, d.y)
	if p.has("accelerate"):
		var a: Vector2 = p.get("accelerate")
		data.accelerate(a.x, a.y)
	if p.has("behavior"):
		var s: Script = load(str(p.get("behavior")))
		if s:
			data.behavior(s)
	return data
