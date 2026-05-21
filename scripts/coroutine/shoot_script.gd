extends CoroutineRunner
class_name ShootScript

func start_shooting(api: StageAPI):
	run(_on_run.bind(api))

func _on_run(_api: StageAPI):
	pass
