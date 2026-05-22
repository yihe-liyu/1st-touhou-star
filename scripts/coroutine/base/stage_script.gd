extends CoroutineRunner
class_name StageScript

func start_stage(api: StageAPI):
	run(_on_run.bind(api))

func _on_run(_api: StageAPI):
	pass
