extends CoroutineRunner
class_name StageScript

func start_stage(api: StageAPI):
	run(_on_step.bind(api))

func _on_step(_api: StageAPI) -> Variant:
	return false
