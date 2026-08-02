class_name WaveTable
extends Control
## 编排波次表：真正的行列样式（列头 + 网格线 + 斑马纹 + 选中高亮）
## 信号给 workbench，由 workbench 负责详情表单/删除/保存

signal wave_selected(idx: int)

const COLUMNS: Array[String] = ["t", "波次", "敌人", "数量", "间隔"]
const COL_WIDTHS: Array[float] = [46.0, 130.0, 96.0, 56.0, 64.0]
const HEADER_H := 26.0
const ROW_H := 24.0

var _tl: Resource
var _scroll: ScrollContainer
var _rows_box: VBoxContainer
var _selected_idx := -1

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
func setup(tl: Resource) -> void:
	_tl = tl
	_selected_idx = -1
	# 重建：清空后重填
	for c in _rows_box.get_children():
		c.queue_free()
	_append_header()
	if _tl == null:
		return
	for i in _tl.waves.size():
		_append_row(i, _tl.waves[i])
	# 高度 = 内容（列头+行）封顶 5 行，多余内部滚动
	var rows: int = _tl.waves.size() if _tl != null else 0
	var h := HEADER_H + ROW_H * float(rows) + 4.0
	h = minf(h, HEADER_H + ROW_H * 5.0 + 4.0)
	custom_minimum_size = Vector2(_total_width(), h)
	_scroll.custom_minimum_size = Vector2(_total_width(), h)
	_update_highlight()


func selected_idx() -> int:
	return _selected_idx


## 选中某行（外部：新增/刷新后恢复选中）
func select_row(idx: int) -> void:
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
	# 整行点击选中
	row.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			select_row(i)
	)
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
		p.set_meta("row", i)  # 选中高亮时定位
		var l := Label.new()
		l.text = texts[c]
		l.add_theme_font_size_override("font_size", 12)
		l.add_theme_color_override("font_color", CELL_TEXT)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		p.add_child(l)
		row.add_child(p)
	_rows_box.add_child(row)


## 选中高亮：更新所有行背景
func _update_highlight() -> void:
	var rows := _rows_box.get_children()
	if rows.is_empty():
		return
	rows.remove_at(0)  # 跳过列头
	var i := 0
	for row in rows:
		if not row is HBoxContainer:
			continue
		var band := BAND_A if i % 2 == 0 else BAND_B
		var fill := SEL_BG if i == _selected_idx else band
		for cell in row.get_children():
			var style := _cell_style(fill)
			if i == _selected_idx:
				style.set_border_width_all(1)
				style.border_color = Color(0.5, 0.8, 1.0, 0.6)
			cell.add_theme_stylebox_override("panel", style)
		i += 1
