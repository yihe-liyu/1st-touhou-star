## 工作台预览画布（@tool）—— 自带 _draw，绘制聚焦生命周期树
## 世界坐标（东方框 64,32 ~ 832,928）→ 画布坐标自动缩放适配 + 居中
@tool
extends Control
class_name WorkbenchCanvas

var focus: LifecycleNode

const WORLD := Rect2(64, 32, 768, 896)  # 东方框世界坐标

var _scale := 1.0       # 世界 → 画布 缩放
var _offset := Vector2.ZERO  # 平移（居中）


## 世界坐标 → 画布坐标（缩放 + 居中）
func _to_screen(p: Vector2) -> Vector2:
	return _offset + p * _scale


func _update_view() -> void:
	var margin := 12.0
	var avail: Vector2 = size - Vector2(margin, margin) * 2.0
	_scale = minf(avail.x / WORLD.size.x, avail.y / WORLD.size.y)
	_offset = (size - WORLD.size * _scale) / 2.0 - WORLD.position * _scale


func _world_rect() -> Rect2:
	return Rect2(_offset + WORLD.position * _scale, WORLD.size * _scale)


func _draw() -> void:
	if focus == null:
		return
	_update_view()
	var wrect := _world_rect()
	# 东方框背景
	draw_rect(wrect, Color(0.08, 0.08, 0.16), true)
	draw_rect(wrect, Color(0.3, 0.3, 0.5, 0.4), false, 1.5)
	# 网格（世界坐标每 64px）
	for x in range(64, 832, 64):
		draw_line(_to_screen(Vector2(x, 32)), _to_screen(Vector2(x, 928)), Color(1, 1, 1, 0.04))
	for y in range(32, 928, 64):
		draw_line(_to_screen(Vector2(64, y)), _to_screen(Vector2(832, y)), Color(1, 1, 1, 0.04))
	# 所有活动节点（DFS 全树）
	var alive: Array = focus.collect_alive()
	for node in alive:
		if node is LifecycleBullet:
			_draw_bullet(node as LifecycleBullet)
		elif node != focus:
			_draw_node_marker(node)


## 通用节点标记（非子弹实体）：小方块 + 存活框
func _draw_node_marker(node: LifecycleNode) -> void:
	# 节点没有位置概念时在东方框中央显示标记（占位；步 3 接入位置行为）
	var pos := _to_screen(Vector2(448, 480))
	var half := 6.0 * _scale
	draw_rect(Rect2(pos - Vector2(half, half), Vector2(half * 2, half * 2)), Color(0.4, 0.7, 1.0, 0.5))
	draw_rect(Rect2(pos - Vector2(half, half), Vector2(half * 2, half * 2)), Color(0.4, 0.7, 1.0), false, 1.0)


func _draw_bullet(b: LifecycleBullet) -> void:
	var p: Vector2 = _to_screen(b.position())
	var r: float = b.radius * _scale
	# 轨迹（最近 24 tick）
	for i in 24:
		var tp: Vector2 = _to_screen(b.position_at(maxf(0.0, b.local_time - i * LifecycleNode.TICK)))
		draw_circle(tp, 1.5, Color(1.0, 0.3, 0.2, 0.15))
	# 弹体
	draw_circle(p, r, Color(1.0, 0.3, 0.2))
	# 命中框
	draw_arc(p, r, 0, TAU, 16, Color(1, 1, 1, 0.4), 1.0)
