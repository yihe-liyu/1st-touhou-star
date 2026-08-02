## 数据驱动关卡解释器 —— 读 StageTimeline 波次表，按 t 生成敌人
## 波次 = 敌人模板（注册表）+ 参数；复用现有 EnemyData/spawn_enemy_data
extends CoroutineScript

const TIMELINE = preload("res://data/stage_demo/stage_timeline.tres")

var _wave_state: Dictionary = {}  # {wave, remaining, interval} 当前波次生成状态


func start(p_ctx: StageContext, p_target: Node2D = null):
	ctx = p_ctx
	if p_target:
		target = p_target
	var tl := start_timeline()
	for wave in TIMELINE.waves:
		var w: Dictionary = wave  # 循环捕获：GDScript 闭包要复制
		tl.at(float(w.t)).do(func():
			_start_wave(w)
		)
	super.start(ctx, target)


func _start_wave(wave: Dictionary) -> void:
	_wave_state = {
		"wave": wave,
		"remaining": int(wave.get("count", 1)),
		"interval": float(wave.get("interval", 0.5)),
	}
	run_parallel(_wave_step.bind(ctx))


## 每帧驱动：生成一个敌人 → 等 interval → 再生成
func _wave_step(_p_ctx: StageContext) -> Variant:
	if _wave_state.is_empty():
		return false
	if int(_wave_state.remaining) <= 0:
		_wave_state = {}
		return false
	_spawn_one(_wave_state.wave)
	_wave_state.remaining = int(_wave_state.remaining) - 1
	return float(_wave_state.interval)


func _spawn_one(wave: Dictionary) -> void:
	var data := EnemyTemplateRegistry.build(str(wave.get("enemy", "")))
	if data == null:
		return
	var params: Dictionary = wave.get("params", {})
	for k in params:
		data.param(k, params[k])
	# 生成位置：默认顶部外居中，可被 spawn_x 覆盖
	data.pos(Vector2(float(wave.get("spawn_x", GameConfig.FIELD_CENTER_X)), -40.0))
	data.spawn(ctx)
