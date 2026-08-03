class_name WorkbenchUI
extends RefCounted
## 工作台 UI 公共工具：统一的小控件工厂（标签/标题/参数行）

const TEXT_DIM := Color(0.65, 0.70, 0.78)
const ACCENT := Color(0.92, 0.73, 0.32)


## 区块标题（金色 + 上间距）：── 状态 ── / ── 书签 ── 等
static func section_title(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", ACCENT)
	l.custom_minimum_size = Vector2(0, 22)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


## 参数标签（右对齐统一宽度，参数行对齐）
static func param_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.custom_minimum_size = Vector2(52, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.add_theme_color_override("font_color", TEXT_DIM)
	return l


## 弱化文字标签（普通说明）
static func label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", TEXT_DIM)
	return l


## SpinBox 行：右对齐标签 + spinbox，挂到 parent，返回 spin
static func spin_row(parent: Node, label_text: String, value: float, min_v: float, max_v: float, step: float) -> SpinBox:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	h.add_child(param_label(label_text))
	var spin := SpinBox.new()
	spin.min_value = min_v
	spin.max_value = max_v
	spin.step = step
	spin.value = value
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(spin)
	parent.add_child(h)
	return spin


## 参数行内的小 SpinBox（Vector2 用，不挂行）
static func mini_spin(value: float, min_v: float, max_v: float) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = min_v
	spin.max_value = max_v
	spin.step = 1.0
	spin.value = value
	spin.custom_minimum_size = Vector2(70, 0)
	return spin


## 参数值标签（键名，用于字典动态表单）
static func param_key_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.custom_minimum_size = Vector2(48, 0)
	l.add_theme_color_override("font_color", TEXT_DIM)
	return l
