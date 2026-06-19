extends CoroutineRunner
class_name StageScript

var ctx: StageContext
var _tl: Timeline

func start_timeline() -> Timeline:
	_tl = Timeline.new(ctx)
	return _tl

func start_stage(p_ctx: StageContext):
	ctx = p_ctx
	run(_on_step.bind(ctx))

func _on_step(_ctx: StageContext) -> Variant:
	if _tl:
		_tl.tick(get_physics_process_delta_time())
	return true

func diff_pick(arr: Array) -> Variant:
	return arr[GameState.selected_difficulty]

func diff_get(dict: Dictionary, key: String, default = null):
	return dict.get(GameState.selected_difficulty, {}).get(key, default)
