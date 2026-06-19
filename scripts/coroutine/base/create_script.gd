extends CoroutineRunner
class_name CreateScript

var ctx  ## StageContext

func start_creating(api: StageAPI, p_ctx = null):
	ctx = p_ctx
	run(_on_step.bind(api))

func _on_step(_api: StageAPI) -> Variant:
	return false
