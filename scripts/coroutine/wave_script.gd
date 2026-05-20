extends CoroutineRunner
class_name WaveScript

func start_wave(api: StageAPI):
	run(_on_run.bind(api))

func _on_run(_api: StageAPI):
	pass
