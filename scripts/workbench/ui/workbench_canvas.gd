## 工作台预览画布（@tool）—— 自带 _draw，绘制聚焦生命周期树
@tool
extends Control
class_name WorkbenchCanvas

var focus: LifecycleNode


func _draw() -> void:
	if focus == null:
		return
	# 东方框背景
	draw_rect(Rect2(64, 32, 768, 896), Color(0.08, 0.08, 0.16), true)
	# 网格
	for x in range(64, 832, 64):
		draw_line(Vector2(x, 32), Vector2(x, 928), Color(1, 1, 1, 0.04))
	for y in range(32, 928, 64):
		draw_line(Vector2(64, y), Vector2(832, y), Color(1, 1, 1, 0.04))
	# 所有活动节点（DFS 全树）
	var alive: Array = focus.collect_alive()
	for node in alive:
		if node is LifecycleBullet:
			_draw_bullet(node as LifecycleBullet)
		elif node != focus:
			# 通用节点标记（发射器/敌人等）：存活指示点
			_draw_node_marker(node)


## 通用节点标记（非子弹实体）：小方块 + 存活框
func _draw_node_marker(node: LifecycleNode) -> void:
	# 节点没有位置概念时在画布中央显示标记（占位；步 3 接入位置行为）
	var pos := Vector2(448, 480)
	draw_rect(Rect2(pos - Vector2(6, 6), Vector2(12, 12)), Color(0.4, 0.7, 1.0, 0.5))
	draw_rect(Rect2(pos - Vector2(6, 6), Vector2(12, 12)), Color(0.4, 0.7, 1.0), false, 1.0)


func _draw_bullet(b: LifecycleBullet) -> void:
	var p: Vector2 = b.position()
	# 轨迹（最近 24 tick）
	for i in 24:
		var tp: Vector2 = b.position_at(maxf(0.0, b.local_time - i * LifecycleNode.TICK))
		draw_circle(tp, 1.5, Color(1.0, 0.3, 0.2, 0.15))
	# 弹体
	draw_circle(p, b.radius, Color(1.0, 0.3, 0.2))
	# 命中框
	draw_arc(p, b.radius, 0, TAU, 16, Color(1, 1, 1, 0.4), 1.0)
