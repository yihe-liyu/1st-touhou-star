extends CoroutineRunner
class_name BackgroundScript
# 背景装饰物协程 —— 覆写 _on_step(api) 来生成装饰物。
# 不自动启动，由调用方显式调用 start_background(api)。

func start_background(api: StageAPI) -> void:
	run(_on_step.bind(api))

func _on_step(_api: StageAPI) -> Variant:
	return false
