extends CoroutineRunner
class_name BackgroundScript
## 背景装饰物协程 —— 挂在 StageBackground 场景下，自动启动
##
## 覆写 _on_step(api) 来生成装饰物。

func _ready() -> void:
	start_background(StageAPI.new(self))

func start_background(api: StageAPI) -> void:
	run(_on_step.bind(api))

func _on_step(_api: StageAPI) -> Variant:
	return false
