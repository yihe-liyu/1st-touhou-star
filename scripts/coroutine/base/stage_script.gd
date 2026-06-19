extends CoroutineRunner
class_name StageScript

var ctx: StageContext

func start_stage(p_ctx: StageContext):
	ctx = p_ctx
	run(_on_step.bind(ctx))

func _on_step(_ctx: StageContext) -> Variant:
	return false
