## 工作台演示生命周期节点（独立文件类，@tool 安全）
extends LifecycleNode
class_name WorkbenchDemoEmitter

## 生成计划：从 t=0.5 起每 0.5s 一颗向上子弹，共 10 颗
func _spawn_plan() -> Array:
	var plan: Array = []
	for i in 10:
		var b := LifecycleBullet.new()
		b.origin = Vector2(448, 600)
		b.velocity = Vector2(-60 + i * 13.0, -240)
		plan.append({"t": 0.5 + i * 0.5, "node": b})
	return plan

## 7 秒后死亡
func _should_die() -> bool:
	return local_time >= 7.0
