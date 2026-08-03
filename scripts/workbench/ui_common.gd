class_name WorkbenchUI
## 工作台 UI 公共工具：统一的小控件工厂（避免各组件重复造 label/spin 行）
extends RefCounted


## 弱化标题文字（面板内区块标题用）
static func label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.modulate = Color(0.7, 0.7, 0.8)
	return l


## SpinBox 行：label + spinbox，挂到 parent，返回 spin（应用时读 .value）
static func spin_row(parent: Node, label_text: String, value: float, min_v: float, max_v: float, step: float) -> SpinBox:
	var h := HBoxContainer.new()
	var l := label(label_text)
	l.custom_minimum_size = Vector2(48, 0)
	h.add_child(l)
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
