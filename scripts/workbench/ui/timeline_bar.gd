## 时间轴条带 —— 工作台时间线（@tool）
## 子对象 = 焦点生命周期上的"条"（锚点→死亡）；点击条 → 聚焦该对象
## 以主对象时间线为锚：子条位置 = 子.anchor / 焦点生命周期长
@tool
extends Control
class_name TimelineBar

## 选中回调（节点）
signal node_selected(node: LifecycleNode)

var focus: LifecycleNode
var time: float = 0.0

const BAR_H := 14.0
const PAD := 10.0


func _draw() -> void:
	if focus == null:
		return
	var total := maxf(focus.duration(), 0.001)
	var w := size.x
	# 轨道背景
	draw_rect(Rect2(0, 0, w, size.y), Color(0.08, 0.08, 0.12))
	# 网格刻度（每 1s）
	var ticks := int(ceil(total))
	for i in ticks + 1:
		var x := i / total * w
		draw_line(Vector2(x, 0), Vector2(x, size.y), Color(1, 1, 1, 0.05))
	# 子对象条
	var cy := size.y / 2.0
	for child in focus.children:
		var x0 := child.anchor / total * w
		var cw := maxf(child.duration() / total * w, 2.0)
		var col := _color_for(child)
		draw_rect(Rect2(x0, cy - BAR_H / 2.0, cw, BAR_H), col)
		draw_rect(Rect2(x0, cy - BAR_H / 2.0, cw, BAR_H), col.darkened(0.5), false, 1.0)
	# 播放头
	var hx := clampf(time / total, 0.0, 1.0) * w
	draw_line(Vector2(hx, 0), Vector2(hx, size.y), Color(1.0, 0.9, 0.4, 0.9), 2.0)


func _gui_input(event: InputEvent) -> void:
	if focus == null:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var total := maxf(focus.duration(), 0.001)
		# 先试点击条（优先于轨道跳转）
		for child in focus.children:
			var x0 := child.anchor / total * size.x
			var cw := maxf(child.duration() / total * size.x, 2.0)
			if event.position.x >= x0 and event.position.x <= x0 + cw:
				node_selected.emit(child)
				return
		# 点轨道 = 跳转时间
		time = clampf(event.position.x / size.x, 0.0, 1.0) * total
		queue_redraw()


func _color_for(node: LifecycleNode) -> Color:
	if node is LifecycleBullet:
		return Color(1.0, 0.3, 0.2, 0.8)
	return Color(0.3, 0.7, 1.0, 0.8)
