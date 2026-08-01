## 工作台演示生命周期节点（独立文件类，@tool 安全）
extends LifecycleNode
class_name WorkbenchDemoEmitter

## 生成计划：每 0.5s 一轮 8 方向环形弹（对称 → 任何时刻画面居中）
func _spawn_plan() -> Array:
	var plan: Array = []
	for round in 8:
		for i in 8:
			var b := LifecycleBullet.new()
			b.origin = Vector2(448, 480)
			var ang := TAU * float(i) / 8.0
			b.velocity = Vector2(cos(ang), sin(ang)) * 240.0
			plan.append({"t": 0.5 + round * 0.5, "node": b})
	return plan

## 行为事件：每轮发射 = 一个事件（编排树/时间线展示）
func _behavior_events() -> Array:
	var events: Array = []
	for round in 8:
		events.append({"t": 0.5 + round * 0.5, "label": "发射环 #%d" % (round + 1)})
	return events

## 7 秒后死亡
func _should_die() -> bool:
	return local_time >= 7.0
