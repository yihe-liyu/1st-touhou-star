extends CoroutineRunner
class_name StageScript

var ctx  ## StageContext

func start_stage(api: StageAPI, p_ctx):
	ctx = p_ctx
	run(_on_step.bind(api))

func _on_step(_api: StageAPI) -> Variant:
	return false
