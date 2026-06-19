extends CoroutineRunner
class_name CreateScript

var ctx: StageContext

func start_creating(p_ctx: StageContext):
	ctx = p_ctx
	run(_on_step.bind(ctx))

func _on_step(_ctx: StageContext) -> Variant:
	return false
