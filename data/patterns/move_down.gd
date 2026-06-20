extends MoveScript
## 向下减速停——参数化，工厂调用

var target_y: float = 400.0
var duration: float = 1.5

func start_moving(p_ctx: StageContext, p_target: Node2D):
	ctx = p_ctx
	target = p_target
	
	var end_pos := Vector2(target.global_position.x, target_y)
	target.create_tween().tween_property(target, "global_position", end_pos, duration) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	
	super.start_moving(p_ctx, target)
