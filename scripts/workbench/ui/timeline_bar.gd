## 时间轴条带 —— 工作台 v2（关卡沙盒版）
##
## 真实关卡不支持任意 seek（协程/状态机/玩家交互），时间轴只做两件事：
##   1. 显示当前游戏内时间（播放头）+ 书签标记（tl.at 时刻）
##   2. 点击任意处 = 快进到该时刻（工作台收到 jump_to 后重跑+加速）
@tool
extends Control
class_name TimelineBar

## 点击时间轴 = 快进到该时刻（非暂停/seek，见 workbench.gd）
signal jump_to(t: float)

var time: float = 0.0                 ## 当前游戏内时间（秒）
var window_len: float = 60.0          ## 时间窗口（秒）
var bookmarks: Array[Dictionary] = [] ## [{t, label}]，升序

const PAD := 8.0


func set_window(seconds: float) -> void:
	window_len = maxf(seconds, 1.0)
	queue_redraw()


func add_bookmark(t: float, label: String) -> void:
	bookmarks.append({"t": t, "label": label})
	bookmarks.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.t < b.t)
	queue_redraw()


func clear_bookmarks() -> void:
	bookmarks.clear()
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var total := maxf(window_len, 0.001)
	var cy := size.y / 2.0
	# 轨道背景
	draw_rect(Rect2(0, 0, w, size.y), Color(0.07, 0.07, 0.11))
	# 刻度（每 1s 细线，每 5s 标数字）
	var ticks := int(ceil(total))
	for i in ticks + 1:
		var x := i / total * w
		draw_line(Vector2(x, 0), Vector2(x, size.y), Color(1, 1, 1, 0.04))
		if i % 5 == 0:
			_draw_tick_label(x, i)
	# 书签：菱形标记（颜色区分：前段敌波=蓝，Boss=红）
	for bm in bookmarks:
		var x := float(bm.t) / total * w
		if x < -6.0 or x > w + 6.0:
			continue
		var is_boss: bool = float(bm.t) >= 35.0
		var col: Color = Color(1.0, 0.4, 0.3, 0.9) if is_boss else Color(0.4, 0.8, 1.0, 0.9)
		draw_colored_polygon(PackedVector2Array([
			Vector2(x, 5), Vector2(x + 6, cy), Vector2(x, size.y - 5), Vector2(x - 6, cy)
		]), col)
	# 播放头（唯一移动的东西）
	var hx := clampf(time / total, 0.0, 1.0) * w
	draw_line(Vector2(hx, 0), Vector2(hx, size.y), Color(1.0, 0.9, 0.4, 0.95), 2.0)


func _draw_tick_label(x: float, sec: int) -> void:
	var font: Font = ThemeDB.fallback_font
	if font == null:
		font = get_theme_default_font()
	if font == null:
		return
	draw_string(font, Vector2(x + 2, 10), str(sec), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.6, 0.6, 0.7))


func _gui_input(event: InputEvent) -> void:
	# 点击/拖动时间轴任意处 = 快进到该时刻
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var total := maxf(window_len, 0.001)
		var t := clampf(event.position.x / maxf(size.x, 1.0), 0.0, 1.0) * total
		jump_to.emit(t)
		accept_event()
