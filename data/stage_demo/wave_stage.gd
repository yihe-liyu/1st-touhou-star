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

var _wave_state: Dictionary = {}  # {wave, remaining, interval} 当前波次生成状态


func start(p_ctx: StageContext, p_target: Node2D = null):
	ctx = p_ctx
	if p_target:
		target = p_target
	var tl := start_timeline()
	for wave in current_timeline().waves:
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
	# 生成位置：spawn_pos [x,y] 优先，否则 spawn_x/spawn_y，默认顶部外居中
	var sx := float(wave.get("spawn_x", GameConfig.FIELD_CENTER_X))
	var sy := float(wave.get("spawn_y", -40.0))
	if wave.has("spawn_pos"):
		var sp: Vector2 = wave.spawn_pos
		sx = sp.x
		sy = sp.y
	data.pos(Vector2(sx, sy))
	data.spawn(ctx)
