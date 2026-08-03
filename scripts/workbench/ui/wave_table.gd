class_name WaveTable
extends Control
## 编排波次表：真正的行列样式（列头 + 网格线 + 斑马纹 + 选中高亮）
## 信号给 workbench，由 workbench 负责详情表单/删除/保存

signal wave_selected(idx: int)
signal boss_row_selected

const COLUMNS: Array[String] = ["t", "波次", "敌人", "数量", "间隔"]
const COL_WIDTHS: Array[float] = [46.0, 130.0, 96.0, 56.0, 64.0]
const HEADER_H := 26.0
const ROW_H := 24.0

var _tl: Resource
var _scroll: ScrollContainer
var _rows_box: VBoxContainer
var _selected_idx := -1
var _boss: BossData
var _boss_selected := false  # Boss 行选中状态（高亮）

# 配色
const HEADER_BG := Color(0.16, 0.24, 0.36, 0.95)
const HEADER_TEXT := Color(0.85, 0.93, 1.0)
const CELL_TEXT := Color(0.9, 0.92, 0.95)
const BAND_A := Color(1, 1, 1, 0.04)
const BAND_B := Color(1, 1, 1, 0.10)
const SEL_BG := Color(0.28, 0.55, 0.95, 0.35)
const HOVER_BG := Color(1, 1, 1, 0.10)


func _init() -> void:
	var h := HEADER_H + ROW_H * 4.0 + 4.0  # 默认高度（约 4 行可见，多余滚动）
	custom_minimum_size = Vector2(_total_width(), h)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.custom_minimum_size = Vector2(_total_width(), h)
	add_child(_scroll)
	_rows_box = VBoxContainer.new()
	_rows_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows_box.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_rows_box.add_theme_constant_override("separation", 0)
	_scroll.add_child(_rows_box)


## 用 timeline 数据重建表格
func setup(tl: Resource, boss: BossData = null) -> void:
	_tl = tl
	_selected_idx = -1
	_boss = boss
	_boss_selected = false
	# 重建：清空后重填
	for c in _rows_box.get_children():
		c.queue_free()
	_append_header()
	if _tl == null:
		return
	# Boss 行（第 0 行，红色）
	if _boss != null:
		_append_boss_row()
	for i in _tl.waves.size():
		_append_row(i, _tl.waves[i])
	# 高度 = 内容（列头+行）封顶 5 行，多余内部滚动
	var rows: int = _tl.waves.size() + (1 if _boss != null else 0)
	var h := HEADER_H + ROW_H * float(rows) + 4.0
	h = minf(h, HEADER_H + ROW_H * 5.0 + 4.0)
	custom_minimum_size = Vector2(_total_width(), h)
	_scroll.custom_minimum_size = Vector2(_total_width(), h)
	_update_highlight()


## Boss 行（红色，点击 → boss_row_selected）
func _append_boss_row() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	row.custom_minimum_size = Vector2(0, ROW_H)
	var texts: Array[String] = [
		"%.1f" % _boss_time_or(20.0),
		"Boss: %s" % _boss.boss_name,
		"Boss", "—", "—",
	]
	for c in texts.size():
		var p := PanelContainer.new()
		p.custom_minimum_size = Vector2(COL_WIDTHS[c], ROW_H)
		var fill := Color(0.35, 0.10, 0.08, 0.85)
		p.add_theme_stylebox_override("panel", _cell_style(fill))
		p.mouse_filter = Control.MOUSE_FILTER_STOP
		p.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				select_boss_row()
		)
		var l := Label.new()
		l.text = texts[c]
		l.add_theme_font_size_override("font_size", 12)
		l.add_theme_color_override("font_color", Color(1.0, 0.75, 0.7))
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		p.add_child(l)
		row.add_child(p)
	_rows_box.add_child(row)


## Boss 行点击：选中（高亮 + 信号）
func select_boss_row() -> void:
	_selected_idx = -1
	_boss_selected = true
	_update_highlight()
	boss_row_selected.emit()


## 清除 Boss 行高亮（选中敌波时）
func clear_boss_selection() -> void:
	if _boss_selected:
		_boss_selected = false
		_update_highlight()


## Boss 行时间（boss_time，表格显示用；无则默认）
func _boss_time_or(default_v: float) -> float:
	return 20.0  # 简化为固定显示（精确时刻由时间轴条带体现）


func boss_selected_state() -> bool:
	return _boss_selected


func selected_idx() -> int:
	return _selected_idx


## 选中某行（外部：新增/刷新后恢复选中）
## 同 idx 守卫：表格/时间轴双向联动时避免递归触发 wave_selected
func select_row(idx: int) -> void:
	if idx == _selected_idx:
		return
	_selected_idx = idx
	_update_highlight()
	wave_selected.emit(idx)


func row_count() -> int:
	return _tl.waves.size() if _tl != null else 0


func _total_width() -> float:
	var w := 0.0
	for cw in COL_WIDTHS:
		w += cw
	return w


## 单元格样式（网格线 = StyleBoxFlat 边框）
static func _cell_style(fill: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.set_border_width_all(1)
	sb.border_color = Color(1, 1, 1, 0.10)
	sb.content_margin_left = 6.0
	sb.content_margin_right = 4.0
	return sb


func _append_header() -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 0)
	for i in COLUMNS.size():
		var p := PanelContainer.new()
		p.custom_minimum_size = Vector2(COL_WIDTHS[i], HEADER_H)
		p.add_theme_stylebox_override("panel", _cell_style(HEADER_BG))
		var l := Label.new()
		l.text = COLUMNS[i]
		l.add_theme_font_size_override("font_size", 12)
		l.add_theme_color_override("font_color", HEADER_TEXT)
		p.add_child(l)
		h.add_child(p)
	_rows_box.add_child(h)


func _append_row(i: int, w: Dictionary) -> void:
	var band := BAND_A if i % 2 == 0 else BAND_B
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	row.custom_minimum_size = Vector2(0, ROW_H)
	var texts: Array[String] = [
		"%.1f" % float(w.get("t", 0.0)),
		str(w.get("name", "波次")),
		str(w.get("enemy", "")),
		str(w.get("count", 1)),
		str(w.get("interval", 0.5)),
	]
	for c in texts.size():
		var p := PanelContainer.new()
		p.custom_minimum_size = Vector2(COL_WIDTHS[c], ROW_H)
		p.add_theme_stylebox_override("panel", _cell_style(band))
		p.mouse_filter = Control.MOUSE_FILTER_STOP
		# 单元格点击 → 选中行（命中即触发，最稳）
		p.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				select_row(i)
		)
		p.set_meta("row", i)  # 选中高亮时定位
		var l := Label.new()
		l.text = texts[c]
		l.add_theme_font_size_override("font_size", 12)
		l.add_theme_color_override("font_color", CELL_TEXT)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		p.add_child(l)
		row.add_child(p)
	_rows_box.add_child(row)


## 选中高亮：更新所有行背景（第 0 行是 Boss 行，用红色系）
func _update_highlight() -> void:
	var rows := _rows_box.get_children()
	if rows.is_empty():
		return
	rows.remove_at(0)  # 跳过列头
	var row_idx := 0
	for row in rows:
		if not row is HBoxContainer:
			continue
		if row_idx == 0 and _boss != null:
			# Boss 行：红色底 + 选中高亮边框
			var bfill := Color(0.35, 0.10, 0.08, 0.85)
			if _boss_selected:
				bfill = Color(0.55, 0.18, 0.12, 0.95)
			for cell in row.get_children():
				var style := _cell_style(bfill)
				if _boss_selected:
					style.set_border_width_all(1)
					style.border_color = Color(1.0, 0.6, 0.5, 0.8)
				cell.add_theme_stylebox_override("panel", style)
		else:
			var i := row_idx - (1 if _boss != null else 0)
			var band := BAND_A if i % 2 == 0 else BAND_B
			var fill := SEL_BG if i == _selected_idx else band
			for cell in row.get_children():
				var style := _cell_style(fill)
				if i == _selected_idx:
					style.set_border_width_all(1)
					style.border_color = Color(0.5, 0.8, 1.0, 0.6)
				cell.add_theme_stylebox_override("panel", style)
		row_idx += 1
