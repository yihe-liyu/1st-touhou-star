class_name WaveForm
extends ScrollContainer
## 波次详情表单：按字段类型动态生成控件；应用时写回 timeline 并发信号
## 只写数据；重跑/保存流程由 Workbench 主控制器决定
##
## 信号：
##   applied(idx)     —— 参数已写回，请求重跑验证
##   save_requested   —— 请求保存 .tres

signal applied(idx: int)

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
	# 名称（波次名：表格/删除弹窗显示用，可编辑）
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 6)
	name_row.add_child(WorkbenchUI.param_label("名称"))
	var name_edit := LineEdit.new()
	name_edit.text = str(w.get("name", ""))
	name_edit.placeholder_text = "波次名"
	name_edit.custom_minimum_size = Vector2(140, 0)
	name_row.add_child(name_edit)
	_body.add_child(name_row)
	_edits.append({"apply": func():
		w["name"] = name_edit.text
	})
	# 基础字段（可编辑）
	_add_field_edit("t", w, "t", 0.0, 90.0, 0.1, false)
	_add_field_edit("数量", w, "count", 1.0, 60.0, 1.0, true)
	_add_field_edit("间隔", w, "interval", 0.0, 10.0, 0.1, false)
	# 敌人模板下拉（注册表）
	_add_enum_edit("敌人", w, "enemy", ENEMY_REG.names(), false)
	# 出生坐标（x/y 一行，带轴标签，不再分两行）
	var spawn_spins: Array = WorkbenchUI.coord_row(_body, "出生",
		float(w.get("spawn_x", GameConfig.FIELD_CENTER_X)),
		float(w.get("spawn_y", -40.0)),
		0.0, 900.0, -100.0, 1000.0)
	_edits.append({"apply": func():
		w["spawn_x"] = spawn_spins[0].value
		w["spawn_y"] = spawn_spins[1].value
	})
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


## 写回数据 + 通知主控制器重跑
func apply_changes() -> void:
	if _tl == null or _idx < 0 or _idx >= _tl.waves.size():
		return
	for entry in _edits:
		entry.apply.call()
	applied.emit(_idx)


## 把表单当前值写回数据（不重跑、不发信号）
## 保存前调用：避免"改了没点应用就保存"丢改动（表单值与数据脱节）
func flush() -> void:
	if _tl == null or _idx < 0 or _idx >= _tl.waves.size():
		return
	for entry in _edits:
		entry.apply.call()


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


## 添加参数弹窗：键名（可点常用快捷按钮）+ 值（类型自动识别）→ 写回并重建表单
func _open_add_param(wave: Dictionary, key: String) -> void:
	var vb := _dialog.open("＋ 添加参数")
	# 输入控件（先声明，供下方 lambda 闭包引用）
	var name_edit := LineEdit.new()
	name_edit.placeholder_text = "如 n / speed / aim"
	var val_edit := LineEdit.new()
	val_edit.placeholder_text = "24 / true / 100,200 / 1,0,0,1"
	# 常用键名快捷按钮（按当前弹幕模式建议）
	var pattern_name := ""
	if _tl and _idx >= 0 and _idx < _tl.waves.size():
		pattern_name = str(_tl.waves[_idx].get("pattern", ""))
	var common := PatternRegistry.suggest_params(pattern_name)
	if not common.is_empty():
		var hint := Label.new()
		hint.text = "点一下填入键名："
		hint.add_theme_font_size_override("font_size", 11)
		hint.modulate = Color(0.5, 0.5, 0.6)
		vb.add_child(hint)
		var common_row := HBoxContainer.new()
		common_row.add_theme_constant_override("separation", 4)
		for pname in common:
			var b := Button.new()
			b.text = str(pname)
			b.add_theme_font_size_override("font_size", 11)
			b.pressed.connect(func(): name_edit.text = str(pname))
			common_row.add_child(b)
		vb.add_child(common_row)
	# 键名行
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 6)
	name_row.add_child(WorkbenchUI.label("键名"))
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(name_edit)
	vb.add_child(name_row)
	# 值行（类型自动识别）
	var val_row := HBoxContainer.new()
	val_row.add_theme_constant_override("separation", 6)
	val_row.add_child(WorkbenchUI.label("值"))
	val_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	val_row.add_child(val_edit)
	vb.add_child(val_row)
	var info := Label.new()
	info.text = "类型自动识别：数字 / true,false / x,y 坐标 / r,g,b,a 颜色"
	info.add_theme_font_size_override("font_size", 11)
	info.modulate = Color(0.5, 0.5, 0.6)
	vb.add_child(info)
	_dialog.add_actions("✓ 添加", func():
		var k := name_edit.text.strip_edges()
		if k.is_empty():
			return
		var dict: Dictionary = wave.get(key, {})
		dict[k] = _infer_param_value(val_edit.text)
		wave[key] = dict
		show_wave(_tl, _idx)  # 重建表单
	)
	name_edit.text_submitted.connect(func(_s: String): _dialog.confirm())
	name_edit.grab_focus()


## 从输入文本自动识别参数类型：int/float/bool/Vector2/Color/String
func _infer_param_value(text: String) -> Variant:
	var t := text.strip_edges()
	if t.is_empty():
		return ""
	var lower := t.to_lower()
	if lower == "true":
		return true
	if lower == "false":
		return false
	if "," in t:
		var parts := t.split(",")
		var nums: Array[float] = []
		for p in parts:
			var f := p.strip_edges().to_float()
			if not is_finite(f):
				return t  # 含非数字 → 当字符串
			nums.append(f)
		if nums.size() == 2:
			return Vector2(nums[0], nums[1])
		if nums.size() >= 3:
			return Color(nums[0], nums[1], nums[2], nums[3] if nums.size() > 3 else 1.0)
		return t
	if t.is_valid_float():
		if t.is_valid_int():
			return int(t)
		return t.to_float()
	return t


## 下拉选择行（敌人模板/弹幕模式等），写回 wave[key]
func _add_enum_edit(label_text: String, wave: Dictionary, key: String, options: Array, allow_empty: bool) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	h.add_child(WorkbenchUI.param_label(label_text))
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
		var spins: Array = WorkbenchUI.vec2_row(_body, key, value)
		_edits.append({"apply": func():
			target[key] = Vector2(spins[0].value, spins[1].value)
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
		h.add_theme_constant_override("separation", 6)
		h.add_child(WorkbenchUI.param_key_label(key))
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
		# 字符串等：LineEdit（固定宽，与 SpinBox 行对齐）
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 6)
		h.add_child(WorkbenchUI.param_key_label(key))
		var line := LineEdit.new()
		line.text = str(value)
		line.custom_minimum_size = Vector2(140, 0)
		h.add_child(line)
		_body.add_child(h)
		_edits.append({"apply": func():
			target[key] = line.text
		})
