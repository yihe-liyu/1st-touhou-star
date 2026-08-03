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

var _tl: Resource
var _idx: int = -1
var _edits: Array = []
var _body: VBoxContainer


func _init() -> void:
	custom_minimum_size = Vector2(0, 140)
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 4)
	add_child(_body)


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
	_add_field_edit("出生x", w, "spawn_x", 0.0, 900.0, 1.0, false)
	_add_field_edit("出生y", w, "spawn_y", -100.0, 1000.0, 1.0, false)
	# 模板参数（按值类型动态生成表单）
	var params: Dictionary = w.get("params", {})
	if not params.is_empty():
		_body.add_child(WorkbenchUI.label("── 模板参数 ──"))
		for k in params:
			_add_param_edit(w, k, params[k])
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

## 基础字段行（SpinBox）
func _add_field_edit(label_text: String, wave: Dictionary, key: String, min_v: float, max_v: float, step: float, as_int: bool) -> void:
	var spin := WorkbenchUI.spin_row(_body, label_text, float(wave.get(key, min_v)), min_v, max_v, step)
	_edits.append({"apply": func():
		if as_int:
			wave[key] = int(spin.value)
		else:
			wave[key] = spin.value
	})


## 模板参数行：按值类型生成控件（float/int/Vector2/bool/String）
func _add_param_edit(wave: Dictionary, key: String, value: Variant) -> void:
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
			wave.params[key] = Vector2(sx.value, sy.value)
		})
	elif value is bool:
		var cb := CheckButton.new()
		cb.text = key
		cb.button_pressed = value
		_body.add_child(cb)
		_edits.append({"apply": func():
			wave.params[key] = cb.button_pressed
		})
	elif typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
		var as_int := typeof(value) == TYPE_INT
		var spin := WorkbenchUI.spin_row(_body, key, float(value), -100000, 100000, 1.0)
		_edits.append({"apply": func():
			if as_int:
				wave.params[key] = int(spin.value)
			else:
				wave.params[key] = spin.value
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
			wave.params[key] = line.text
		})
