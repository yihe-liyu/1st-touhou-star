extends CoroutineRunner
class_name BackgroundScript
## 背景装饰物协程
##
## _on_init(api)  → 场景加载后立即调用, 协程未启动, 只做同步设置(禁止 seconds/frames)
## _on_step(api)  → 协程主循环，返回 float(true/false 同 CoroutineRunner 约定
##
## 不自动启动，由 StageBackground._on_setup() 调 _on_init，
## StageManager 调 start_background()。

var ctx  ## StageContext

func start_background(api: StageAPI, p_ctx) -> void:
	ctx = p_ctx
	run(_on_step.bind(api))

func _on_init(_api: StageAPI) -> void:
	pass

func _on_step(_api: StageAPI) -> Variant:
	return false
