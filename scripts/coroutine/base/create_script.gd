extends CoroutineRunner
class_name CreateScript

func start_creating(api: StageAPI):
	run(_on_step.bind(api))

func _on_step(_api: StageAPI) -> Variant:
	return false
