## 时间轴 —— 工作台（关卡沙盒版）
##
## 双态：
##   折叠（32px）：细条，刻度 + 播放头 + 书签菱形 + 点击跳转（预览友好）
##   展开（88px）：总谱视图，波次条带 + 重叠自动分行 + 选中高亮 + 拖拽改 t
##
## 真实关卡不支持任意 seek（协程/状态机/玩家交互），时间轴只做两件事：
##   1. 显示当前游戏内时间（播放头）+ 书签标记 + 波次分布
##   2. 点击 = 快进到该时刻；点条带 = 选中波次；拖条带 = 改 t
##
## 信号：
##   jump_to(t)          —— 点击空白/折叠态点击 → 快进
##   right_clicked(t)    —— 右键 → 添加人工书签
##   wave_selected(idx)  —— 点击波次条带 → 选中（表格/表单联动）
##   wave_moved(idx, t)  —— 拖拽松手 → 已写回 waves[idx].t，请求刷新表格
@tool
extends Control
class_name TimelineBar

signal jump_to(t: float)
signal right_clicked(t: float)
signal wave_selected(idx: int)
signal wave_moved(idx: int, t: float)
signal boss_selected
signal boss_moved(idx: int, t: float)

var time: float = 0.0                 ## 当前游戏内时间（秒）
var window_start: float = 0.0         ## 时间窗口起点（滚动/缩放后）
var window_len: float = 60.0          ## 时间窗口（秒）
var bookmarks: Array[Dictionary] = [] ## [{t, label}]，升序

## 波次数据（StageTimeline.waves 的浅拷贝；元素是共享引用 → 拖拽写回即改数据源）
var waves: Array = []
## Boss 条带列表（多 Boss；每项 {t, duration}，时间轴第 0 行，红色）
var _boss_bands: Array = []
## 演出事件标记（bgm=绿 / dialogue=紫 / custom=黄）
var events: Array = []
var expanded: bool = false:
	set(v):
		if expanded == v:
			return
		expanded = v
		_refresh_layout()
		if _toggle:
			_toggle.button_pressed = v
			_toggle.text = "收起" if v else "总谱"
## 选中的波次索引（表格/时间轴双向联动）
var selected_wave: int = -1:
	set(v):
		selected_wave = v
		queue_redraw()

const COLLAPSED_H := 32.0
const EXPANDED_H := 120.0
const PAD := 8.0
## 条带轨道区参数（展开态）
const TRACK_TOP := 3.0
const TRACK_ROW_H := 17.0
const TRACK_BAND_H := 14.0
## 最多可见轨道行（超出折叠为溢出提示；固定面板高度避免拖拽时 UI 跳变）
const MAX_TRACKS := 4
const TICK_Y := 88.0   # 展开态刻度区起点（轨道区之下）

var _toggle: Button
# 拖拽状态（条带）
var _drag_idx := -1
var _drag_mouse_start := 0.0
var _drag_t_start := 0.0
var _drag_t_preview := -1.0
var _moved := false
# Boss 条带状态（_drag_boss_idx >= 0 = 正在拖第几条）
var _drag_boss_idx: int = -1
var _boss_drag_preview := -1.0
var _boss_selected_flag := false
# 平移状态（空白拖动浏览时间窗口）
var _panning := false
var _pan_mouse_start := 0.0
var _pan_start_ws := 0.0
var _pan_moved := false
const PAN_CLICK_TOLERANCE := 4.0  # 超过该像素位移才算拖动（否则视为点击）


func _ready() -> void:
	set_process(true)  # 播放跟随窗口平移
	_toggle = Button.new()
	_toggle.toggle_mode = true
	_toggle.text = "总谱"
	_toggle.button_pressed = expanded
	_toggle.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_toggle.offset_left = -66.0
	_toggle.offset_right = -4.0
	_toggle.offset_top = 4.0
	_toggle.offset_bottom = 24.0
	_toggle.toggled.connect(func(on: bool): expanded = on)
	add_child(_toggle)
	_refresh_layout()


## 折叠/展开布局：高度切换（锚点底部固定，向上生长）
func _refresh_layout() -> void:
	var h := EXPANDED_H if expanded else COLLAPSED_H
	custom_minimum_size = Vector2(0, h)
	offset_top = -h
	queue_redraw()


## 设置波次数据（数据关卡传 timeline.waves；协程关卡传 [] → 总谱禁用）
func set_waves(w: Array) -> void:
	waves = w.duplicate()
	if expanded and waves.is_empty():
		expanded = false
	if _toggle:
		_toggle.disabled = waves.is_empty()
	queue_redraw()


## 设置 Boss 条带（有 Boss 时传时刻+阶段总时长；无 Boss 传 t<0）
## 设置 Boss 条带列表（多 Boss）：[{t, duration}]（自动按 t 排序）
func set_bosses(list: Array) -> void:
	_boss_bands.clear()
	for e in list:
		_boss_bands.append({"t": float(e.get("t", 0.0)), "duration": maxf(float(e.get("duration", 20.0)), 1.0)})
	_boss_bands.sort_custom(func(a: Dictionary, b: Dictionary): return a["t"] < b["t"])
	_boss_selected_flag = false
	queue_redraw()


## 兼容：单 Boss 设置
func set_boss(t: float, duration: float = 20.0) -> void:
	set_bosses([{"t": t, "duration": duration}])


## 设置演出事件（StageTimeline.events）
func set_events(evs: Array) -> void:
	events = evs.duplicate()
	queue_redraw()


## Boss 选中状态（workbench 编辑切换用）
func set_boss_selected(selected: bool) -> void:
	_boss_selected_flag = selected
	queue_redraw()


func set_window(seconds: float) -> void:
	window_len = maxf(seconds, 1.0)
	window_start = 0.0
	queue_redraw()


## 播放跟随：播放头接近窗口边缘时平移窗口
func _process(_delta: float) -> void:
	if time > window_start + window_len * 0.95:
		window_start = maxf(0.0, time - window_len * 0.5)
		queue_redraw()
	elif time < window_start:
		window_start = maxf(0.0, time - window_len * 0.1)
		queue_redraw()


func add_bookmark(t: float, label: String) -> void:
	bookmarks.append({"t": t, "label": label})
	bookmarks.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.t < b.t)
	queue_redraw()


func clear_bookmarks() -> void:
	bookmarks.clear()
	queue_redraw()


# ═══ 绘制 ═══

func _draw() -> void:
	var w := size.x
	var cy := size.y / 2.0
	# 轨道背景
	draw_rect(Rect2(0, 0, w, size.y), Color(0.07, 0.07, 0.11))
	if expanded:
		_draw_tracks(w)
		_draw_ticks(w, TICK_Y, size.y - 2.0)
		_draw_events(w, TICK_Y, size.y - 2.0)
		_draw_bookmark_diamonds(w, TICK_Y + (size.y - 2.0 - TICK_Y) / 2.0)
	else:
		_draw_ticks(w, 0.0, size.y)
		_draw_events(w, 0.0, size.y)
		_draw_bookmark_diamonds(w, cy)
	# 播放头（唯一移动的东西，贯穿全高）
	var hx := clampf((time - window_start) / maxf(window_len, 0.001), 0.0, 1.0) * w
	draw_line(Vector2(hx, 0), Vector2(hx, size.y), Color(1.0, 0.9, 0.4, 0.95), 2.0)


## 演出事件标记（小方块：bgm 绿 / 对话 紫 / 自定义 黄）
func _draw_events(w: float, y0: float, y1: float) -> void:
	var cy := y0 + (y1 - y0) / 2.0
	for ev in events:
		var t := float(ev.get("t", 0.0))
		var x := (t - window_start) / maxf(window_len, 0.001) * w
		if x < -6.0 or x > w + 6.0:
			continue
		var col := Color(0.4, 1.0, 0.5, 0.9)
		match str(ev.get("type", "")):
			"dialogue":
				col = Color(0.75, 0.5, 1.0, 0.9)
			"custom":
				col = Color(1.0, 0.8, 0.3, 0.9)
		draw_rect(Rect2(x - 3, cy - 3, 6, 6), col)


## 波次条带：重叠自动分行（贪心），颜色按敌人类型分类
## 只画可见轨道（MAX_TRACKS 行），超出画溢出提示
## 第 0 行固定给 Boss 条带（红色），敌波从第 1 行起
## 拖拽中的条带用预览位置绘制（_drag_t_preview，不写回数据源）
func _draw_tracks(w: float) -> void:
	_draw_boss_bands(w)
	var rows := _visible_rows()
	for r in rows.size():
		var y := TRACK_TOP + TRACK_ROW_H + r * TRACK_ROW_H
		for band in rows[r]:
			var t: float = float(band.t)
			var is_dragging: bool = band.idx == _drag_idx and _drag_t_preview >= 0.0
			if is_dragging:
				t = _drag_t_preview
			var x := _x(t, w)
			var bw := maxf(band.dur / maxf(window_len, 0.001) * w, 3.0)
			var col := _band_color(band.enemy)
			var rect := Rect2(x, y, bw, TRACK_BAND_H)
			# 部分在窗口外也画（裁切交给 Godot），但完全在左侧外的不画
			if x + bw < -2.0 or x > w + 2.0:
				continue
			draw_rect(rect, col)
			if band.idx == selected_wave or is_dragging:
				draw_rect(rect, Color(1, 1, 1, 0.95), false, 1.5)
			if bw > 26.0:
				var font: Font = _font()
				if font:
					# 拖拽中显示实时 t 值，方便对齐
					var label: String = "%.1fs" % t if is_dragging else band.name
					draw_string(font, Vector2(x + 4.0, y + 11.0), label,
						HORIZONTAL_ALIGNMENT_LEFT, bw - 6.0, 10, Color(1, 1, 1, 0.92))
	# 溢出提示
	var overflow := _overflow_count()
	if overflow > 0:
		var font: Font = _font()
		if font:
			draw_string(font, Vector2(w - 118.0, 13.0), "⚠ +%d 重叠未显示" % overflow,
				HORIZONTAL_ALIGNMENT_LEFT, 108.0, 10, Color(1.0, 0.7, 0.3, 0.95))


## Boss 条带：第 0 行红色（拖拽中显示实时 t）
func _draw_boss_bands(w: float) -> void:
	var font: Font = _font()
	for bi in _boss_bands.size():
		var band: Dictionary = _boss_bands[bi]
		var t := _boss_drag_preview if (_drag_boss_idx == bi and _boss_drag_preview >= 0.0) else float(band["t"])
		var x := _x(t, w)
		var bw := maxf(float(band["duration"]) / maxf(window_len, 0.001) * w, 4.0)
		var y := TRACK_TOP
		var rect := Rect2(x, y, bw, TRACK_BAND_H)
		if x + bw < -2.0 or x > w + 2.0:
			continue
		draw_rect(rect, Color(1.0, 0.32, 0.25, 0.85))
		if _boss_selected_flag or _drag_boss_idx == bi:
			draw_rect(rect, Color(1, 1, 1, 0.95), false, 1.5)
		if font and bw > 34.0:
			var label: String = "Boss%d %.1fs" % [bi + 1, t] if _drag_boss_idx == bi else "Boss%d" % (bi + 1)
			draw_string(font, Vector2(x + 4.0, y + 11.0), label,
				HORIZONTAL_ALIGNMENT_LEFT, bw - 6.0, 10, Color(1, 1, 1, 0.95))


## 条带行布局：贪心分行（不与上一行重叠）
func _layout_rows() -> Array:
	if waves.is_empty():
		return []
	# 带原始索引排序（拖拽/选中需要 waves 数组序）
	var sorted: Array = []
	for i in waves.size():
		sorted.append({"idx": i, "data": waves[i]})
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.data.get("t", 0.0)) < float(b.data.get("t", 0.0)))
	var rows: Array = []
	for s in sorted:
		var t := float(s.data.get("t", 0.0))
		var dur := maxf(float(s.data.get("count", 1)) * float(s.data.get("interval", 0.5)), 1.0)
		var band := {"idx": s.idx, "t": t, "dur": dur,
			"name": str(s.data.get("name", "")), "enemy": str(s.data.get("enemy", ""))}
		var placed := false
		for row in rows:
			var ok := true
			for b in row:
				if t < b.t + b.dur + 0.15 and t + dur > b.t - 0.15:
					ok = false
					break
			if ok:
				row.append(band)
				placed = true
				break
		if not placed:
			rows.append([band])
	return rows


## 可见轨道行：最多 MAX_TRACKS 行（超出折叠为溢出提示）
func _visible_rows() -> Array:
	var rows := _layout_rows()
	if rows.size() <= MAX_TRACKS:
		return rows
	return rows.slice(0, MAX_TRACKS)


## 溢出（未显示）的波次行数
func _overflow_count() -> int:
	return maxi(_layout_rows().size() - MAX_TRACKS, 0)


## 命中测试：位置 → 波次索引（-1 = 空白）
## 只测可见行：溢出行不参与命中（避免刻度区误触）
## 敌波从第 1 行起（第 0 行给 Boss）
func _hit_band(pos: Vector2) -> int:
	if not expanded or waves.is_empty():
		return -1
	for r in _visible_rows().size():
		var y := TRACK_TOP + TRACK_ROW_H + r * TRACK_ROW_H
		if pos.y < y or pos.y > y + TRACK_BAND_H:
			continue
		for band in _visible_rows()[r]:
			var x := _x(band.t, size.x)
			var bw := maxf(band.dur / maxf(window_len, 0.001) * size.x, 3.0)
			if pos.x >= x and pos.x <= x + bw:
				return band.idx
	return -1


## Boss 条带命中（第 0 行）：返回条带索引，无则 -1
func _boss_hit(pos: Vector2) -> int:
	if not expanded:
		return -1
	var y := TRACK_TOP
	if pos.y < y or pos.y > y + TRACK_BAND_H:
		return -1
	for bi in _boss_bands.size():
		var band: Dictionary = _boss_bands[bi]
		var x := _x(float(band["t"]), size.x)
		var bw := maxf(float(band["duration"]) / maxf(window_len, 0.001) * size.x, 4.0)
		if pos.x >= x and pos.x <= x + bw:
			return bi
	return -1


## 敌人类型 → 条带颜色（按模板名前缀分类）
func _band_color(enemy: String) -> Color:
	var e := enemy.to_lower()
	if e.contains("boss"):
		return Color(1.0, 0.35, 0.3, 0.8)
	if e.contains("red"):
		return Color(0.95, 0.4, 0.35, 0.7)
	if e.contains("blue"):
		return Color(0.4, 0.65, 1.0, 0.7)
	if e.contains("green"):
		return Color(0.4, 0.9, 0.5, 0.7)
	if e.contains("gold") or e.contains("yellow"):
		return Color(1.0, 0.85, 0.3, 0.7)
	if e.contains("white"):
		return Color(0.9, 0.9, 0.95, 0.7)
	if e.contains("purple") or e.contains("jade"):
		return Color(0.75, 0.5, 1.0, 0.7)
	return Color(0.6, 0.75, 0.9, 0.6)


func _draw_ticks(w: float, y0: float, y1: float) -> void:
	var ticks := int(ceil(window_len))
	for i in ticks + 1:
		var x := i / maxf(window_len, 0.001) * w
		draw_line(Vector2(x, y0), Vector2(x, y1), Color(1, 1, 1, 0.04))
		if i % 5 == 0:
			_draw_tick_label(x, int(window_start) + i)


func _draw_bookmark_diamonds(w: float, cy: float) -> void:
	for bm in bookmarks:
		var x := (float(bm.t) - window_start) / maxf(window_len, 0.001) * w
		if x < -6.0 or x > w + 6.0:
			continue
		var is_boss: bool = float(bm.t) >= 35.0
		var col: Color = Color(1.0, 0.4, 0.3, 0.9) if is_boss else Color(0.4, 0.8, 1.0, 0.9)
		draw_colored_polygon(PackedVector2Array([
			Vector2(x, cy - 5), Vector2(x + 5, cy), Vector2(x, cy + 5), Vector2(x - 5, cy)
		]), col)


func _draw_tick_label(x: float, sec: int) -> void:
	var font: Font = _font()
	if font == null:
		return
	draw_string(font, Vector2(x + 2, 10), str(sec), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.6, 0.6, 0.7))


func _font() -> Font:
	var font: Font = ThemeDB.fallback_font
	if font == null:
		font = get_theme_default_font()
	return font


## 时刻 → 像素 x（当前窗口）
func _x(t: float, w: float) -> float:
	return (t - window_start) / maxf(window_len, 0.001) * w


# ═══ 输入 ═══

func _gui_input(event: InputEvent) -> void:
	# 拖拽中（motion）：Boss 条带 / 敌波条带 / 空白平移
	if event is InputEventMouseMotion:
		if _drag_boss_idx >= 0:
			var bm := event as InputEventMouseMotion
			var bdx: float = bm.position.x - _drag_mouse_start
			var bdt: float = bdx / maxf(size.x, 1.0) * window_len
			_boss_drag_preview = clampf(_drag_t_start + bdt, 0.0, 9999.0)
			_moved = true
			queue_redraw()
			accept_event()
			return
		if _drag_idx >= 0:
			var mm := event as InputEventMouseMotion
			var dx: float = mm.position.x - _drag_mouse_start
			var dt: float = dx / maxf(size.x, 1.0) * window_len
			_drag_t_preview = clampf(_drag_t_start + dt, 0.0, 9999.0)  # 预览平滑跟随（不吸附，跟手）
			_moved = true
			queue_redraw()
			accept_event()
			return
		if _panning:
			var pm := event as InputEventMouseMotion
			if absf(pm.position.x - _pan_mouse_start) > PAN_CLICK_TOLERANCE:
				_pan_moved = true
			if _pan_moved:
				var pdx: float = pm.position.x - _pan_mouse_start
				var pdt: float = pdx / maxf(size.x, 1.0) * window_len
				# 右拖 → 窗口向过去移（内容跟随鼠标向右）
				window_start = maxf(0.0, _pan_start_ws - pdt)
				queue_redraw()
			accept_event()
			return
	# 松开：Boss/条带写回或选中；空白 pan 结束或点击跳转
	if event is InputEventMouseButton and not event.pressed:
		if _drag_boss_idx >= 0:
			var bmoved := _moved
			var bpreview := _boss_drag_preview
			var bidx := _drag_boss_idx
			_drag_boss_idx = -1
			_boss_drag_preview = -1.0
			_moved = false
			if bmoved and bpreview >= 0.0:
				boss_moved.emit(bidx, snappedf(bpreview, 0.5))
			else:
				boss_selected.emit()
			accept_event()
			return
		if _drag_idx >= 0:
			var idx := _drag_idx
			var moved := _moved
			var preview := _drag_t_preview
			_drag_idx = -1
			_drag_t_preview = -1.0
			_moved = false
			if moved and preview >= 0.0 and idx < waves.size():
				waves[idx]["t"] = snappedf(preview, 0.5)  # 松手才吸附 0.5s 网格（共享引用 → 数据源已更新）
				wave_moved.emit(idx, snappedf(preview, 0.5))
			elif not moved:
				wave_selected.emit(idx)
			accept_event()
			return
		if _panning:
			var pan_moved := _pan_moved
			var pos: Vector2 = (event as InputEventMouseButton).position
			_stop_pan()
			if not pan_moved:
				jump_to.emit(_x_to_time(pos.x))  # 轻点（无拖动）= 快进跳转
			accept_event()
			return
		return
	if not (event is InputEventMouseButton and event.pressed):
		return
	match event.button_index:
		MOUSE_BUTTON_LEFT:
			if expanded:
				# Boss 条带优先（第 0 行）
				var bhit := _boss_hit(event.position)
				if bhit >= 0:
					_drag_boss_idx = bhit
					_drag_mouse_start = event.position.x
					_drag_t_start = float(_boss_bands[bhit]["t"])
					_boss_drag_preview = -1.0
					_moved = false
					_boss_selected_flag = true  # 高亮先行
					accept_event()
					return
			if expanded and not waves.is_empty():
				var hit := _hit_band(event.position)
				if hit >= 0:
					_drag_idx = hit
					_drag_mouse_start = event.position.x
					_drag_t_start = float(waves[hit].get("t", 0.0))
					_drag_t_preview = -1.0
					_moved = false
					selected_wave = hit  # 高亮先行，表格等释放后跟随
					accept_event()
					return
			# 空白：按住拖动 = 平移时间窗口；轻点 = 快进（松开时判定）
			_start_pan(event.position.x)
			accept_event()
		MOUSE_BUTTON_RIGHT:
			right_clicked.emit(_x_to_time(event.position.x))
			accept_event()
		MOUSE_BUTTON_WHEEL_UP:
			_zoom(event.position.x, 0.8)
			accept_event()
		MOUSE_BUTTON_WHEEL_DOWN:
			_zoom(event.position.x, 1.25)
			accept_event()


## 空白按下：开始平移（记录起点，松手判定点击/拖动）
func _start_pan(mouse_x: float) -> void:
	_panning = true
	_pan_mouse_start = mouse_x
	_pan_start_ws = window_start
	_pan_moved = false


func _stop_pan() -> void:
	_panning = false
	_pan_moved = false


## 滚轮缩放：以鼠标位置为中心缩放时间窗口
func _zoom(mouse_x: float, factor: float) -> void:
	var ratio := clampf(mouse_x / maxf(size.x, 1.0), 0.0, 1.0)
	var anchor_t := window_start + ratio * window_len  # 鼠标处时刻保持不动
	window_len = clampf(window_len * factor, 5.0, 600.0)
	window_start = maxf(0.0, anchor_t - ratio * window_len)
	queue_redraw()


## 像素 x → 时刻（含窗口起点）
func _x_to_time(x: float) -> float:
	var total := maxf(window_len, 0.001)
	return window_start + clampf(x / maxf(size.x, 1.0), 0.0, 1.0) * total
