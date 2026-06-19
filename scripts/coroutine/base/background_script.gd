extends CoroutineRunner
class_name BackgroundScript
## 背景协程 —— 内置 Timeline 支持
##
## _on_init(ctx) → 场景加载后立即调用, 协程未启动
## _on_step(ctx) → 协程主循环（如不用 Timeline 可覆写）

var ctx: StageContext
var _tl: Timeline

func start_timeline() -> Timeline:
	_tl = Timeline.new(ctx)
	return _tl

func start_background(p_ctx: StageContext) -> void:
	ctx = p_ctx
	run(_on_step.bind(ctx))

func _on_init(_ctx: StageContext) -> void:
	pass

func _on_step(_ctx: StageContext) -> Variant:
	if _tl:
		_tl.tick(get_physics_process_delta_time())
	return true
