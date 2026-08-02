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
## 右键点击时间轴 = 在该时刻添加人工书签
signal right_clicked(t: float)

var time: float = 0.0                 ## 当前游戏内时间（秒）
var window_start: float = 0.0         ## 时间窗口起点（滚动/缩放后）
var window_len: float = 60.0          ## 时间窗口（秒）
var bookmarks: Array[Dictionary] = [] ## [{t, label}]，升序

const PAD := 8.0


func _ready() -> void:
	set_process(true)  # 播放跟随窗口平移


func set_window(seconds: float) -> void:
	window_len = maxf(seconds, 1.0)
	window_start = 0.0
	queue_redraw()


## 播放跟随：播放头接近窗口边缘时平移窗口
func _process(_delta: float) -> void:
	if time > window_start + window_len * 0.95:
		window_start = time - window_len * 0.5
		queue_redraw()
	elif time < window_start:
		window_start = time - window_len * 0.1
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
	var ticks := int(ceil(window_len))
	for i in ticks + 1:
		var x := i / total * w
		draw_line(Vector2(x, 0), Vector2(x, size.y), Color(1, 1, 1, 0.04))
		if i % 5 == 0:
			_draw_tick_label(x, int(window_start) + i)
	# 书签：菱形标记（颜色区分：前段敌波=蓝，Boss=红）
	for bm in bookmarks:
		var x := (float(bm.t) - window_start) / total * w
		if x < -6.0 or x > w + 6.0:
			continue
		var is_boss: bool = float(bm.t) >= 35.0
		var col: Color = Color(1.0, 0.4, 0.3, 0.9) if is_boss else Color(0.4, 0.8, 1.0, 0.9)
		draw_colored_polygon(PackedVector2Array([
			Vector2(x, 5), Vector2(x + 6, cy), Vector2(x, size.y - 5), Vector2(x - 6, cy)
		]), col)
	# 播放头（唯一移动的东西）
	var hx := clampf((time - window_start) / total, 0.0, 1.0) * w
	draw_line(Vector2(hx, 0), Vector2(hx, size.y), Color(1.0, 0.9, 0.4, 0.95), 2.0)


func _draw_tick_label(x: float, sec: int) -> void:
	var font: Font = ThemeDB.fallback_font
	if font == null:
		font = get_theme_default_font()
	if font == null:
		return
	draw_string(font, Vector2(x + 2, 10), str(sec), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.6, 0.6, 0.7))


func _gui_input(event: InputEvent) -> void:
	# 左键：跳转
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		jump_to.emit(_x_to_time(event.position.x))
		accept_event()
	# 右键：在该时刻添加人工书签
	elif event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_RIGHT:
		right_clicked.emit(_x_to_time(event.position.x))
		accept_event()
	# 滚轮：缩放时间窗口（上=放大局部，下=缩小回全貌），以鼠标位置为中心
	elif event is InputEventMouseButton and event.pressed \
			and (event.button_index == MOUSE_BUTTON_WHEEL_UP \
				or event.button_index == MOUSE_BUTTON_WHEEL_DOWN):
		var ratio := clampf(event.position.x / maxf(size.x, 1.0), 0.0, 1.0)
		var anchor_t := window_start + ratio * window_len  # 鼠标处时刻保持不动
		var factor := 0.8 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.25
		window_len = clampf(window_len * factor, 5.0, 600.0)
		window_start = anchor_t - ratio * window_len
		queue_redraw()
		accept_event()


## 像素 x → 时刻（含窗口起点）
func _x_to_time(x: float) -> float:
	var total := maxf(window_len, 0.001)
	return window_start + clampf(x / maxf(size.x, 1.0), 0.0, 1.0) * total
