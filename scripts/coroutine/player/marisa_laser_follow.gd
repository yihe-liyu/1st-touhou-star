extends CoroutineScript
class_name MarisaLaserFollow
## 魔理沙非 focus 激光段：锚定自机 + 向上漂移（支持逐段生长无缝衔接）
## 每段相对自机的偏移由 bullet.extra["laser_offset"] 传入
## 整体向上漂移速度由 bullet.extra["drift_speed"] 传入（0 则不漂移）
## 初始漂移量由 bullet.extra["drift_offset"] 传入（生长时继承上一段，保证无缝）
## 每帧把当前漂移量写回 bullet.extra["drift"]（供下一段继承）

var _drift: float = 0.0


func start(p_ctx: StageContext, p_target: Node2D = null):
	ctx = p_ctx
	if p_target:
		target = p_target
	_drift = 0.0
	var extra_init: Variant = target.get("extra")
	if extra_init is Dictionary:
		_drift = extra_init.get("drift_offset", 0.0)

	var tl := start_timeline()
	tl.every(0).do(func():
		if not ctx.active() or not is_instance_valid(target):
			return false
		var player := ctx.player.get_player()
		if not is_instance_valid(player):
			return false
		var off: Vector2 = Vector2.ZERO
		var drift_speed: float = 0.0
		var extra: Variant = target.get("extra")
		if extra is Dictionary:
			off = extra.get("laser_offset", Vector2.ZERO)
			drift_speed = extra.get("drift_speed", 0.0)
		# 向上漂移累积（同速 → 段间相对位置不变 → 无缝）
		_drift += drift_speed * get_physics_process_delta_time()
		target.global_position = player.global_position + off + Vector2(0, -_drift)
		# 写回当前漂移，供后续生长的段继承
		if extra is Dictionary:
			extra["drift"] = _drift
		return true
	)
	super.start(ctx, target)
