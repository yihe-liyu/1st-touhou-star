extends CoroutineRunner
class_name MoveScript

var target: Node2D
var ctx: StageContext
var _tl: Timeline

func start_timeline() -> Timeline:
	_tl = Timeline.new(ctx)
	return _tl

func start_moving(p_ctx: StageContext, p_target: Node2D):
	ctx = p_ctx
	target = p_target
	run(_on_step.bind(ctx))

func _on_step(_ctx: StageContext) -> Variant:
	if _tl:
		_tl.tick(get_physics_process_delta_time())
	return true

func diff_pick(arr: Array) -> Variant:
	return arr[GameState.selected_difficulty]
