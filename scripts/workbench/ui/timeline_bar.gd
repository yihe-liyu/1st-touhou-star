## 时间轴条带 —— 工作台时间线（@tool）
## 子对象 = 焦点生命周期上的"条"（锚点→死亡）；点击条 → 聚焦该对象
## 以主对象时间线为锚：子条位置 = 子.anchor / 焦点生命周期长
@tool
extends Control
class_name TimelineBar

## 选中回调（节点）
signal node_selected(node: LifecycleNode)
## 时间跳转（点击轨道任意处 = seek）
signal time_seeked(t: float)

var focus: LifecycleNode
var time: float = 0.0
var window_len: float = 15.0  ## 固定时间窗口（秒）：刻度/条位稳定，播放头移动

const BAR_H := 14.0
const PAD := 10.0


func _draw() -> void:
	if focus == null:
		return
	var total := maxf(window_len, 0.001)  # 固定窗口 → 刻度/条位稳定
	var w := size.x
	# 轨道背景
	draw_rect(Rect2(0, 0, w, size.y), Color(0.08, 0.08, 0.12))
	# 固定刻度（每 1s）
	var ticks := int(ceil(total))
	for i in ticks + 1:
		var x := i / total * w
		draw_line(Vector2(x, 0), Vector2(x, size.y), Color(1, 1, 1, 0.05))
		if i % 5 == 0:
			draw_string(ThemeDB.fallback_font, Vector2(x + 2, 10), str(i), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.6, 0.6, 0.7))
	var cy := size.y / 2.0
	# 主对象自身条（高亮：整个生命周期范围）
	var self_x0 := clampf((focus.anchor if focus.parent else 0.0) / total * w, 0.0, w)
	var self_cw := maxf(focus.duration() / total * w, 2.0)
	draw_rect(Rect2(self_x0, cy - BAR_H / 2.0, self_cw, BAR_H), Color(1.0, 0.9, 0.4, 0.25))
	draw_rect(Rect2(self_x0, cy - BAR_H / 2.0, self_cw, BAR_H), Color(1.0, 0.9, 0.4, 0.6), false, 1.0)
	# 子对象条（按锚点在固定窗口内定位；超出窗口的截断）
	for child in focus.children:
		var x0 := child.anchor / total * w
		var cw := maxf(child.duration() / total * w, 2.0)
		var col := _color_for(child)
		draw_rect(Rect2(x0, cy - BAR_H / 2.0, cw, BAR_H), col)
		draw_rect(Rect2(x0, cy - BAR_H / 2.0, cw, BAR_H), col.darkened(0.5), false, 1.0)
	# 行为事件点（◆ 沿时间线：行为的节奏）
	var events: Array = focus._behavior_events()
	for ev in events:
		var ex: float = ev.t / total * w
		if ex >= 0.0 and ex <= w:
			draw_colored_polygon(PackedVector2Array([
				Vector2(ex, 4), Vector2(ex + 7, 8), Vector2(ex, 12)
			]), Color(1.0, 0.8, 0.3, 0.9))
	# 播放头（唯一移动的东西）
	var hx := clampf(time / total, 0.0, 1.0) * w
	draw_line(Vector2(hx, 0), Vector2(hx, size.y), Color(1.0, 0.9, 0.4, 0.9), 2.0)


var _dragging: bool = false


func _gui_input(event: InputEvent) -> void:
	if focus == null:
		return
	# 点击/拖动时间线任意处 = seek（不切换主对象；主对象由左侧编排树选择）
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_dragging = true
			_seek_to_x(event.position.x)
			accept_event()
		else:
			_dragging = false
	elif event is InputEventMouseMotion and _dragging:
		_seek_to_x(event.position.x)
		accept_event()


func _seek_to_x(x: float) -> void:
	var total := maxf(window_len, 0.001)
	time = clampf(x / size.x, 0.0, 1.0) * total
	time_seeked.emit(time)
	queue_redraw()


func _color_for(node: LifecycleNode) -> Color:
	if node is LifecycleBullet:
		return Color(1.0, 0.3, 0.2, 0.8)
	return Color(0.3, 0.7, 1.0, 0.8)
