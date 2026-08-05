extends CoroutineScript
## Boss 移动：每隔 jump_interval 秒随机跳到游戏框上部的一个随机坐标
## 用 RNG（可复现：固定种子下序列一致）；tween 物理模式平滑移动（time_scale 同步）
## auto_stop = false（持续运行直到 phase 结束）

var jump_interval: float = 4.0  # 跳跃间隔（秒）
var move_time: float = 1.5      # 单次移动耗时（秒，tween 时长）
var top_min_y: float = 180.0    # 目标 y 下限（上部）
var top_max_y: float = 270.0    # 目标 y 上限

var _t: float = 0.0


func _tick(p_ctx: StageContext):
	if not target:
		return p_ctx.clock.wait(jump_interval)
	_t += get_dt()
	if _t >= jump_interval:
		_t = 0.0
		_jump()
	return true


## 随机目标：x 在游戏框内留边距，y 在顶部区间
func _jump() -> void:
	var dest := Vector2(
		RNG.randf_range(GameConfig.FIELD_LEFT + 60.0, GameConfig.FIELD_RIGHT - 60.0),
		RNG.randf_range(top_min_y, top_max_y))
	var tw := target.create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(target, "global_position", dest, move_time)
