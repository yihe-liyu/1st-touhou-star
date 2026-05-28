extends CoroutineRunner
class_name MoveScript

var target: Node2D

func start_moving(api: StageAPI, p_target: Node2D):
	target = p_target
	run(_on_step.bind(api))

func _on_step(_api: StageAPI) -> Variant:
	return false
