extends CoroutineRunner
class_name MoveScript

var target: Node2D
var ctx: StageContext

func start_moving(p_ctx: StageContext, p_target: Node2D):
	ctx = p_ctx
	target = p_target
	run(_on_step.bind(ctx))

func _on_step(_ctx: StageContext) -> Variant:
	return false
