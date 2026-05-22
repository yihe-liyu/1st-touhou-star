extends CoroutineRunner
class_name CreateScript

func start_creating(api: StageAPI):
	run(_on_run.bind(api))

func _on_run(_api: StageAPI):
	pass
