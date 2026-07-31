extends CoroutineScript
class_name MarisaLaserFollow
## 魔理沙非 focus 激光段：锚定自机跟随
## 每段相对自机的偏移由 bullet.extra["laser_offset"] 传入


func start(p_ctx: StageContext, p_target: Node2D = null):
	ctx = p_ctx
	if p_target:
		target = p_target

	var tl := start_timeline()
	tl.every(0).do(func():
		if not ctx.active() or not is_instance_valid(target):
			return false
		var player := ctx.player.get_player()
		if not is_instance_valid(player):
			return false
		var off: Vector2 = Vector2.ZERO
		var extra: Variant = target.get("extra")
		if extra is Dictionary:
			off = extra.get("laser_offset", Vector2.ZERO)
		target.global_position = player.global_position + off
		return true
	)
	super.start(ctx, target)
