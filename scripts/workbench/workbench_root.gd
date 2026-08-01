## 工作台演示树根：发射器通过生成计划声明（确定性重跑自动重建）
extends LifecycleNode
class_name WorkbenchDemoRoot

var child_plan: Array = []

func _spawn_plan() -> Array:
	return child_plan

func _should_die() -> bool:
	return false
