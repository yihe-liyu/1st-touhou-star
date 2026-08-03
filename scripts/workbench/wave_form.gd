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
		# 弹幕参数（建议按钮直接点，自定义兜底）
		var pattern_name := str(w.get("pattern", ""))
		_add_param_section("── 弹幕参数 ──", w, "pattern_params",
			"形状：n 弹数 / speed 速度 / aim 自机狙", PatternRegistry.suggest_params(pattern_name))
		_add_param_section("── 弹丸配置 ──", w, "bullet_params",
			"子弹外观：tex 贴图 / color 颜色 / behavior 飞行行为", ["tex", "color", "blend", "speed"])
	# 模板参数（敌人模板自带，通常已在）
	_add_param_section("── 模板参数 ──", w, "params", "敌人模板参数（如 target_y / target_pos）")


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

## 参数区：建议参数按钮（点击即添加）+ 已添加参数行（可删）+ 自定义入口
## suggest：该栏推荐属性名（如弹幕参数的 n/speed/aim）
func _add_param_section(title: String, wave: Dictionary, key: String, desc: String = "", suggest: Array = []) -> void:
	_body.add_child(WorkbenchUI.section_title(title))
	if not desc.is_empty():
		var d := Label.new()
		d.text = desc
		d.add_theme_font_size_override("font_size", 11)
		d.modulate = Color(0.55, 0.58, 0.66)
		_body.add_child(d)
	var dict: Dictionary = wave.get(key, {})
	# 建议参数按钮：点一下立即添加该键（默认值），已存在则禁用
	if not suggest.is_empty():
		var sug_row := HBoxContainer.new()
		sug_row.add_theme_constant_override("separation", 4)
		var sug_label := Label.new()
		sug_label.text = "建议："
		sug_label.add_theme_font_size_override("font_size", 11)
		sug_label.modulate = Color(0.55, 0.58, 0.66)
		sug_row.add_child(sug_label)
		for sk in suggest:
			var sb := Button.new()
			sb.text = str(sk)
			sb.add_theme_font_size_override("font_size", 11)
			sb.disabled = dict.has(str(sk))
			sb.tooltip_text = "添加 %s 参数" % sk
			sb.pressed.connect(func(): _add_suggest_param(wave, key, str(sk)))
			sug_row.add_child(sb)
		_body.add_child(sug_row)
	# 已添加参数行（带删除按钮）
	if dict.is_empty():
		var hint := Label.new()
		hint.text = "（空，使用默认值；可点上方建议或下方自定义添加）"
		hint.add_theme_font_size_override("font_size", 11)
		hint.modulate = Color(0.5, 0.5, 0.6)
		_body.add_child(hint)
	else:
		for k in dict:
			_add_param_edit(dict, k, dict[k])
	# 自定义参数入口（弹窗：键名 + 值自动识别类型）
	var add_row := HBoxContainer.new()
	add_row.add_child(_add_param_btn(wave, key))
	_body.add_child(add_row)


## 建议按钮点击：给该键添加默认值并重建表单
func _add_suggest_param(wave: Dictionary, key: String, pname: String) -> void:
	var dict: Dictionary = wave.get(key, {})
	dict[pname] = _suggest_default(pname)
	wave[key] = dict
	show_wave(_tl, _idx)


## 建议参数的默认值（合理起步，改一次就记住）
func _suggest_default(pname: String) -> Variant:
	match pname:
		"n": return 24
		"arms": return 2
		"speed": return 300.0
		"spread": return 30.0
		"step": return 12.0
		"aim": return false
		"random_start": return false
		"tex": return "小玉"
		"blend": return true
		"color": return Color(1, 1, 1, 1)
		"behavior": return ""
	return 0.0


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


## 参数行：按值类型生成控件（float/int/Vector2/bool/Color/String）+ 行尾删除按钮
## target 是写回的字典（模板参数/弹幕参数/弹丸配置通用）
func _add_param_edit(target: Dictionary, key: String, value: Variant) -> void:
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
	_body.add_child(row)


## x/y 轴小标签（坐标行用）
func _axis_label(axis: String) -> Label:
	var l := Label.new()
	l.text = axis
	l.custom_minimum_size = Vector2(12, 0)
	l.add_theme_color_override("font_color", Color(0.45, 0.50, 0.60))
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l
