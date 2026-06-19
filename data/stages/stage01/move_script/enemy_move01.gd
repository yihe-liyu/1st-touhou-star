extends MoveScript

## 向下减速移动至目标 Y，然后停住

var target_y: float = 200.0
var duration: float = 1.5

var _wait: float


func start_moving(p_ctx: StageContext, p_target: Node2D):
	ctx = p_ctx
	target = p_target

	var end_pos := Vector2(target.global_position.x, target_y)
	target.create_tween().tween_property(target, "global_position", end_pos, duration) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

	_wait = duration
	run(_on_step.bind(ctx))


func _on_step(_ctx: StageContext) -> Variant:
	return ctx.clock.wait(_wait)
