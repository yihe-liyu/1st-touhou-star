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
	# 数据预设（.tres：外观/血量/判定/掉落）+ 行为（移动+发弹脚本）自由组合
	var behavior_name := str(w.get("behavior", ""))
	_add_enum_edit("数据", w, "enemy", EnemyTemplateRegistry.data_names(), false)
	_add_enum_edit("行为", w, "behavior", EnemyTemplateRegistry.behavior_names(), false)
	# 出生坐标（x/y 一行，带轴标签，不再分两行）
	var spawn_spins: Array = WorkbenchUI.coord_row(_body, "出生",
		float(w.get("spawn_x", GameConfig.FIELD_CENTER_X)),
		float(w.get("spawn_y", -40.0)),
		0.0, 900.0, -100.0, 1000.0)
	_edits.append({"apply": func():
		w["spawn_x"] = spawn_spins[0].value
		w["spawn_y"] = spawn_spins[1].value
	})
	# 模板参数（行为脚本 var 反射暴露，改参即续跑）
	_add_param_section("── 模板参数 ──", w, "params",
		EnemyTemplateRegistry.suggest_params(behavior_name))


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

## 参数区：建议参数按钮（点击即添加）+ 已添加参数行（可删）
## suggest：该栏推荐属性（Dictionary：键 → 默认值，来自模式/模板 schema）
func _add_param_section(title: String, wave: Dictionary, key: String, suggest: Dictionary = {}) -> void:
	_body.add_child(WorkbenchUI.section_title(title))
	var dict: Dictionary = wave.get(key, {})
	# 参数区卡片（theme PanelContainer 卡片样式，视觉分组）
	var card := PanelContainer.new()
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	card.add_child(vb)
	_body.add_child(card)
	# 建议参数按钮（点一下添加该键，已存在则禁用）
	if not suggest.is_empty():
		var sug_row := HBoxContainer.new()
		sug_row.add_theme_constant_override("separation", 4)
		for sk in suggest:
			var sb := Button.new()
			sb.text = str(sk)
			sb.add_theme_font_size_override("font_size", 12)
			sb.disabled = dict.has(str(sk))
			sb.tooltip_text = "添加 %s 参数" % sk
			sb.pressed.connect(func(): _add_suggest_param(wave, key, str(sk), suggest[str(sk)]))
			sug_row.add_child(sb)
		vb.add_child(sug_row)
	# 已添加参数行（带删除按钮）
	if dict.is_empty():
		var hint := Label.new()
		hint.text = "空（点上方参数添加）"
		hint.add_theme_font_size_override("font_size", 12)
		hint.modulate = Color(0.5, 0.5, 0.6)
		vb.add_child(hint)
	else:
		for k in dict:
			_add_param_edit(dict, k, dict[k], vb)
func _add_suggest_param(wave: Dictionary, key: String, pname: String, default_value: Variant) -> void:
	var dict: Dictionary = wave.get(key, {})
	dict[pname] = default_value
	wave[key] = dict
	show_wave(_tl, _idx)


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


## 参数行：按值类型生成控件（float/int/Vector2/bool/Color/String）+ 行尾删除按钮
## target 是写回的字典（模板参数/弹幕参数/弹丸配置通用）；parent 默认 _body
func _add_param_edit(target: Dictionary, key: String, value: Variant, parent: Node = null) -> void:
	parent = parent if parent != null else _body
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	# ── 内容控件按类型填充 ──
	if value is Vector2:
		row.add_child(WorkbenchUI.param_key_label(key))
		row.add_child(_axis_label("x"))
		var sx := WorkbenchUI.mini_spin(value.x, -10000, 10000)
		row.add_child(sx)
		row.add_child(_axis_label("y"))
		var sy := WorkbenchUI.mini_spin(value.y, -10000, 10000)
		row.add_child(sy)
		_edits.append({"apply": func():
			target[key] = Vector2(sx.value, sy.value)
		})
	elif value is bool:
		var cb := CheckButton.new()
		cb.text = key
		cb.button_pressed = value
		row.add_child(cb)
		_edits.append({"apply": func():
			target[key] = cb.button_pressed
		})
	elif value is Color:
		row.add_child(WorkbenchUI.param_key_label(key))
		var picker := ColorPickerButton.new()
		picker.color = value
		picker.custom_minimum_size = Vector2(72, 0)
		row.add_child(picker)
		_edits.append({"apply": func():
			target[key] = picker.color
		})
	elif typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
		var as_int := typeof(value) == TYPE_INT
		row.add_child(WorkbenchUI.param_key_label(key))
		var spin := SpinBox.new()
		spin.min_value = -100000
		spin.max_value = 100000
		spin.step = 1.0
		spin.value = value
		spin.custom_minimum_size = Vector2(120, 0)
		row.add_child(spin)
		_edits.append({"apply": func():
			if as_int:
				target[key] = int(spin.value)
			else:
				target[key] = spin.value
		})
	else:
		# 字符串等：LineEdit（固定宽，与数值行对齐）
		row.add_child(WorkbenchUI.param_key_label(key))
		var line := LineEdit.new()
		line.text = str(value)
		line.custom_minimum_size = Vector2(140, 0)
		row.add_child(line)
		_edits.append({"apply": func():
			target[key] = line.text
		})
	# ── 统一：行尾删除按钮（移除该参数并重建表单）──
	var del := Button.new()
	del.text = "×"
	del.add_theme_font_size_override("font_size", 11)
	del.custom_minimum_size = Vector2(22, 0)
	del.tooltip_text = "删除参数 %s" % key
	del.pressed.connect(func():
		target.erase(key)
		show_wave(_tl, _idx)  # 重建表单
	)
	row.add_child(del)
	parent.add_child(row)


## x/y 轴小标签（坐标行用）
func _axis_label(axis: String) -> Label:
	var l := Label.new()
	l.text = axis
	l.custom_minimum_size = Vector2(12, 0)
	l.add_theme_color_override("font_color", Color(0.45, 0.50, 0.60))
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l
