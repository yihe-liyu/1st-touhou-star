extends CoroutineScript
class_name MarisaLaserFollow
## 魔理沙非 focus 激光段：锚定发射口（子机/自机）+ 向上漂移
## 支持逐段生长无缝衔接（继承上一段漂移）
## bullet.extra：
##   laser_offset  相对锚点的偏移
##   drift_speed   向上漂移速度
##   drift_offset  初始漂移（生长继承用）
##   anchor_node   发射口节点（子机）；无效时回退自机
##   drift         每帧写回当前漂移（供下一段继承）

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
		var extra: Variant = target.get("extra")
		var off: Vector2 = Vector2.ZERO
		var drift_speed: float = 0.0
		var anchor: Vector2 = Vector2.ZERO
		var anchor_found := false
		if extra is Dictionary:
			off = extra.get("laser_offset", Vector2.ZERO)
			drift_speed = extra.get("drift_speed", 0.0)
			var anchor_node: Variant = extra.get("anchor_node")
			if anchor_node != null and is_instance_valid(anchor_node):
				anchor = anchor_node.global_position
				anchor_found = true
		if not anchor_found:
			# 回退：锚定自机
			var player := ctx.player.get_player()
			if not is_instance_valid(player):
				return false
			anchor = player.global_position
		# 向上漂移累积（同速 → 段间相对位置不变 → 无缝）
		_drift += drift_speed * get_physics_process_delta_time()
		target.global_position = anchor + off + Vector2(0, -_drift)
		# 写回当前漂移，供后续生长的段继承
		if extra is Dictionary:
			extra["drift"] = _drift
		return true
	)
	super.start(ctx, target)
