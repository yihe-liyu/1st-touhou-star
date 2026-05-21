extends CoroutineRunner
class_name LevelScript

func start_level(api: StageAPI):
	run(_on_run.bind(api))

func _on_run(_api: StageAPI):
	pass
