extends CoroutineRunner
class_name MoveScript

var target: Node2D
var ctx  ## StageContext

func start_moving(api: StageAPI, p_target: Node2D, p_ctx = null):
	ctx = p_ctx
	target = p_target
	run(_on_step.bind(api))

func _on_step(_api: StageAPI) -> Variant:
	return false
