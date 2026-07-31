extends CoroutineScript
class_name MarisaLaserFollow
## 魔理沙非 focus 激光段：从发射口（子机）生成，向上漂移
## 每段 drift 从 0 开始（根部在子机），段间距 = 漂移速度 × 生成间隔（自动无缝）
## bullet.extra：
##   anchor_node   发射口节点（子机），无效时回退自机
##   laser_offset  相对锚点偏移（默认 (0,0) = 在发射口生成）
##   drift_speed   向上漂移速度

var _drift: float = 0.0


func start(p_ctx: StageContext, p_target: Node2D = null):
	ctx = p_ctx
	if p_target:
		target = p_target
	_drift = 0.0

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
			var player := ctx.player.get_player()
			if not is_instance_valid(player):
				return false
			anchor = player.global_position
		# 位置 = 发射口 + 偏移 + 向上漂移（drift 独立累积）
		target.global_position = anchor + off + Vector2(0, -_drift)
		_drift += drift_speed * get_physics_process_delta_time()
		return true
	)
	super.start(ctx, target)
