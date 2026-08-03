class_name WaveForm
extends ScrollContainer
## 波次详情表单：按字段类型动态生成控件；应用时写回 timeline 并发信号
## 只写数据；重跑/保存流程由 Workbench 主控制器决定
##
## 信号：
##   applied(idx)     —— 参数已写回，请求重跑验证
##   save_requested   —— 请求保存 .tres

signal applied(idx: int)
signal save_requested

const ENEMY_REG = preload("res://scripts/data/enemy_template_registry.gd")

var _tl: Resource
var _idx: int = -1
var _edits: Array = []
var _body: VBoxContainer
var _dialog: DialogHost


func _init() -> void:
	custom_minimum_size = Vector2(0, 140)
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 4)
	add_child(_body)
	_dialog = DialogHost.new()
	add_child(_dialog)


## 滚轮事件全部吞掉：内层表单滚到底时不触发外层面板滚动（嵌套滚动穿透）
## 手动滚动（不依赖 super：C++ 父类 _gui_input 不可 super 调用）+ accept 截断冒泡
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event.button_index == MOUSE_BUTTON_WHEEL_UP \
			or event.button_index == MOUSE_BUTTON_WHEEL_DOWN):
		var dir := -1.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0
		scroll_vertical += int(dir * 60.0)
		accept_event()


## 清空表单（重跑/加载后）
func clear() -> void:
	_tl = null
	_idx = -1
	_edits.clear()
	for c in _body.get_children():
		c.queue_free()


## 显示指定波次的表单（重建）
func show_wave(tl: Resource, idx: int) -> void:
	_tl = tl
	_idx = idx
	_edits.clear()
	for c in _body.get_children():
		c.queue_free()
	if tl == null or idx < 0 or idx >= tl.waves.size():
		return
	var w: Dictionary = tl.waves[idx]
	# 基础字段（可编辑）
	_add_field_edit("t", w, "t", 0.0, 90.0, 0.1, false)
	_add_field_edit("数量", w, "count", 1.0, 60.0, 1.0, true)
	_add_field_edit("间隔", w, "interval", 0.0, 10.0, 0.1, false)
	# 敌人模板下拉（注册表）
	_add_enum_edit("敌人", w, "enemy", ENEMY_REG.names(), false)
	_add_field_edit("出生x", w, "spawn_x", 0.0, 900.0, 1.0, false)
	_add_field_edit("出生y", w, "spawn_y", -100.0, 1000.0, 1.0, false)
	# 弹幕模式（可选：追加到敌人模板弹幕之上）
	_add_enum_edit("弹幕", w, "pattern", PatternRegistry.names(), true)
	if not str(w.get("pattern", "")).is_empty():
		_add_field_edit("弹幕间隔", w, "pattern_interval", 0.05, 10.0, 0.05, false)
	# 弹幕参数（空也可添加；复用值类型动态表单）
	if not str(w.get("pattern", "")).is_empty():
		_add_param_section("── 弹幕参数 ──", w, "pattern_params")
		_add_param_section("── 弹丸配置 ──", w, "bullet_params")
	# 模板参数
	_add_param_section("── 模板参数 ──", w, "params")
	# 按钮行
	var row := HBoxContainer.new()
	var apply := Button.new()
	apply.text = "✔ 应用"
	apply.pressed.connect(func(): apply_changes())
	row.add_child(apply)
	var save := Button.new()
	save.text = "💾 保存"
	save.pressed.connect(func(): save_requested.emit())
	row.add_child(save)
	_body.add_child(row)


## 写回数据 + 通知主控制器重跑
func apply_changes() -> void:
	if _tl == null or _idx < 0 or _idx >= _tl.waves.size():
		return
	for entry in _edits:
		entry.apply.call()
	applied.emit(_idx)


# ═══ 表单生成 ═══

## 参数区：动态表单；空字典显示提示 + 「＋ 添加参数」按钮（新波次选弹幕后可配参数）
func _add_param_section(title: String, wave: Dictionary, key: String) -> void:
	_body.add_child(WorkbenchUI.label(title))
	var dict: Dictionary = wave.get(key, {})
	if dict.is_empty():
		var row := HBoxContainer.new()
		var hint := Label.new()
		hint.text = "（空，使用默认值）"
		hint.modulate = Color(0.5, 0.5, 0.6)
		row.add_child(hint)
		row.add_child(_add_param_btn(wave, key))
		_body.add_child(row)
		return
	for k in dict:
		_add_param_edit(dict, k, dict[k])
	var add_row := HBoxContainer.new()
	add_row.add_child(_add_param_btn(wave, key))
	_body.add_child(add_row)


func _add_param_btn(wave: Dictionary, key: String) -> Button:
	var btn := Button.new()
	btn.text = "＋ 添加参数"
	btn.pressed.connect(func(): _open_add_param(wave, key))
	return btn


## 添加参数弹窗：键名 + 值类型 + 值 → 写回 wave[key] 并重建表单
func _open_add_param(wave: Dictionary, key: String) -> void:
	var vb := _dialog.open("＋ 添加参数")
	var name_row := HBoxContainer.new()
	name_row.add_child(WorkbenchUI.label("键名"))
	var name_edit := LineEdit.new()
	name_edit.placeholder_text = "如 n / speed / aim"
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(name_edit)
	vb.add_child(name_row)
	var type_row := HBoxContainer.new()
	type_row.add_child(WorkbenchUI.label("类型"))
	var type_opt := OptionButton.new()
	for t in ["float", "int", "bool", "String", "Vector2", "Color"]:
		type_opt.add_item(t)
	type_row.add_child(type_opt)
	vb.add_child(type_row)
	var val_row := HBoxContainer.new()
	val_row.add_child(WorkbenchUI.label("值"))
	var val_edit := LineEdit.new()
	val_edit.placeholder_text = "24 / true / 100,200 / 1,0,0,1"
	val_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	val_row.add_child(val_edit)
	vb.add_child(val_row)
	_dialog.add_actions("✓ 添加", func():
		var k := name_edit.text.strip_edges()
		if k.is_empty():
			return
		var parsed: Variant = _parse_param_value(type_opt.selected, val_edit.text)
		if parsed == null and type_opt.selected != 3:
			return  # 解析失败（String 允许空）
		var dict: Dictionary = wave.get(key, {})
		dict[k] = parsed
		wave[key] = dict
		show_wave(_tl, _idx)  # 重建表单
	)
	name_edit.text_submitted.connect(func(_s: String): _dialog.confirm())
	name_edit.grab_focus()


## 按类型解析输入文本
func _parse_param_value(type_idx: int, text: String) -> Variant:
	match type_idx:
		0:  # float
			return text.to_float()
		1:  # int
			return int(text.to_float())
		2:  # bool
			return text == "true" or text == "1" or text == "yes"
		3:  # String
			return text
		4:  # Vector2 "x,y"
			var parts := text.split(",")
			if parts.size() >= 2:
				return Vector2(float(parts[0].strip_edges()), float(parts[1].strip_edges()))
			return null
		5:  # Color "r,g,b[,a]"
			var cparts := text.split(",")
			if cparts.size() >= 3:
				return Color(float(cparts[0].strip_edges()), float(cparts[1].strip_edges()),
					float(cparts[2].strip_edges()), float(cparts[3].strip_edges()) if cparts.size() > 3 else 1.0)
			return null
	return null


## 下拉选择行（敌人模板/弹幕模式等），写回 wave[key]
func _add_enum_edit(label_text: String, wave: Dictionary, key: String, options: Array, allow_empty: bool) -> void:
	var h := HBoxContainer.new()
	h.add_child(WorkbenchUI.label(label_text))
	var opt := OptionButton.new()
	opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if allow_empty:
		opt.add_item("无")
	var current := str(wave.get(key, ""))
	var cur_idx := -1
	for o in options:
		opt.add_item(str(o))
		if str(o) == current:
			cur_idx = opt.item_count - 1
	if cur_idx >= 0:
		opt.selected = cur_idx
	elif not allow_empty and opt.item_count > 0:
		opt.selected = 0
	h.add_child(opt)
	_body.add_child(h)
	_edits.append({"apply": func():
		if allow_empty and opt.selected == 0:
			wave[key] = ""
		else:
			wave[key] = str(opt.get_item_text(opt.selected))
	})


## 基础字段行（SpinBox）
func _add_field_edit(label_text: String, wave: Dictionary, key: String, min_v: float, max_v: float, step: float, as_int: bool) -> void:
	var spin := WorkbenchUI.spin_row(_body, label_text, float(wave.get(key, min_v)), min_v, max_v, step)
	_edits.append({"apply": func():
		if as_int:
			wave[key] = int(spin.value)
		else:
			wave[key] = spin.value
	})


## 参数行：按值类型生成控件（float/int/Vector2/bool/Color/String）
## target 是写回的字典（模板参数/弹幕参数/弹丸配置通用）
func _add_param_edit(target: Dictionary, key: String, value: Variant) -> void:
	if value is Vector2:
		var h := HBoxContainer.new()
		var l := WorkbenchUI.label(key)
		l.custom_minimum_size = Vector2(48, 0)
		h.add_child(l)
		var sx := WorkbenchUI.mini_spin(value.x, -10000, 10000)
		var sy := WorkbenchUI.mini_spin(value.y, -10000, 10000)
		h.add_child(sx)
		h.add_child(sy)
		_body.add_child(h)
		_edits.append({"apply": func():
			target[key] = Vector2(sx.value, sy.value)
		})
	elif value is bool:
		var cb := CheckButton.new()
		cb.text = key
		cb.button_pressed = value
		_body.add_child(cb)
		_edits.append({"apply": func():
			target[key] = cb.button_pressed
		})
	elif value is Color:
		var h := HBoxContainer.new()
		h.add_child(WorkbenchUI.label(key))
		var picker := ColorPickerButton.new()
		picker.color = value
		picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(picker)
		_body.add_child(h)
		_edits.append({"apply": func():
			target[key] = picker.color
		})
	elif typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
		var as_int := typeof(value) == TYPE_INT
		var spin := WorkbenchUI.spin_row(_body, key, float(value), -100000, 100000, 1.0)
		_edits.append({"apply": func():
			if as_int:
				target[key] = int(spin.value)
			else:
				target[key] = spin.value
		})
	else:
		# 字符串等：LineEdit
		var h := HBoxContainer.new()
		h.add_child(WorkbenchUI.label(key))
		var line := LineEdit.new()
		line.text = str(value)
		line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(line)
		_body.add_child(h)
		_edits.append({"apply": func():
			target[key] = line.text
		})
