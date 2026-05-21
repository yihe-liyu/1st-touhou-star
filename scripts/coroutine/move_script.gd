extends CoroutineRunner
class_name MoveScript

var target: Node2D

func start_moving(api: StageAPI, p_target: Node2D):
	target = p_target
	run(_on_run.bind(api))

func _on_run(_api: StageAPI):
	pass
