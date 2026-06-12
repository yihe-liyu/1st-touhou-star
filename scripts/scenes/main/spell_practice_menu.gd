# SpellPracticeMenu.gd
extends Control

@onready var _stage_box: VBoxContainer = $StageBox
@onready var _phase_box: VBoxContainer = $PhaseBox
@onready var _diff_box: VBoxContainer = $DiffBox
@onready var _char_label: Label = $CharPanel/CharName

enum Section { STAGE, PHASE, DIFF }
var _section: int = Section.STAGE
var _stage_index: int = 0
var _phase_index: int = 0
var _diff_index: int = 0
var _char_index: int = 0
var _ready: bool = false

const DIFF_NAMES := SpellRecord.DIFF_NAMES
const CHAR_NAMES := SpellRecord.CHAR_NAMES
var _stages: Array = []
var _phases: Array = []


func _on_enter() -> void:
	_build_data()
	_char_label.text = "← %s →" % CHAR_NAMES[_char_index]
	_build_lists()
	_highlight()
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.3)
	tw.tween_callback(func(): _ready = true)

func _on_leave() -> void:
	_ready = false
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.2)
	tw.tween_callback(queue_free)

# ═══ 数据 ═══

func _build_data() -> void:
	# TODO: 从真实关卡数据读取
	_stages = [
		{name="Stage 1", num=1, phases=_get_test_phases()},
		{name="Stage 2", num=2, phases=[]},
	]
	_stage_index = 0
	_change_stage(0)

func _get_test_phases() -> Array:
	var p1 := PhaseData.new(); p1.spell_names = ["", "", "", ""]; p1.spell_id = 0
	var p2 := PhaseData.new(); p2.spell_names = ["梦符「Easy」", "梦符「Normal」", "梦符「Hard」", "梦符「Lunatic」"]; p2.spell_id = 1
	var p3 := PhaseData.new(); p3.spell_names = ["结界「Easy」", "结界「Normal」", "结界「Hard」", "结界「Lunatic」"]; p3.spell_id = 2
	return [p1, p2, p3]

func _change_stage(idx: int) -> void:
	_stage_index = idx
	_phases = _stages[idx].get("phases", [])
	_phase_index = 0
	_build_phase_list()

# ═══ 构建列表 ═══

func _build_lists() -> void:
	_clear(_stage_box)
	for s in _stages:
		var lbl := _make_label(s.name)
		var book: Resource = GameState.spell_book
		var records: Array = book.get_by_stage(_char_index, s.num)
		var cap := 0
		var att := 0
		for r in records:
			cap += r.get("captures")
			att += r.get("attempts")
		var suffix := ""
		if att > 0:
			suffix = "  %d/%d" % [cap, att]
		lbl.text += suffix
		_stage_box.add_child(lbl)
	_build_phase_list()

func _build_phase_list() -> void:
	_clear(_phase_box)
	var spell_c := 0
	var non_c := 0
	var stage_num: int = _stages[_stage_index].get("num", 1) if _stage_index < _stages.size() else 1
	var book: Resource = GameState.spell_book
	
	for i in _phases.size():
		var nm: String = _phases[i].get("name") if _phases[i].has_method("get") else ""
		var suffix := ""
		# 显示该符卡所有难度合计
		var cap := 0
		var att := 0
		for d in range(4):
			var r = book.get_record(_char_index, stage_num, i + 1, d)
			if r:
				cap += r.get("captures")
				att += r.get("attempts")
		if att > 0:
			suffix = "  %d/%d" % [cap, att]
		
		if nm == "":
			non_c += 1
			_phase_box.add_child(_make_label("非符%d%s" % [non_c, suffix]))
		else:
			spell_c += 1
			_phase_box.add_child(_make_label("符卡%d%s" % [spell_c, suffix]))

func _build_diff_list() -> void:
	_clear(_diff_box)
	if _phase_index >= _phases.size(): return
	var names = _phases[_phase_index].get("spell_names")
	if not names is Array: return
	var stage_num: int = _stages[_stage_index].get("num", 1) if _stage_index < _stages.size() else 1
	var book: Resource = GameState.spell_book
	
	for i in names.size():
		var vbox := VBoxContainer.new()
		var nl := Label.new()
		nl.text = names[i] if names[i] != "" else "-"
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nl.add_theme_font_size_override("font_size", 18)
		vbox.add_child(nl)
		
		var hl := Label.new()
		var r = book.get_record(_char_index, stage_num, _phase_index + 1, i)
		var capture_str := ""
		if r:
			capture_str = "%d/%d" % [r.get("captures"), r.get("attempts")]
		hl.text = "%s  %s" % [DIFF_NAMES[i], capture_str]
		hl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		hl.add_theme_font_size_override("font_size", 12)
		hl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		vbox.add_child(hl)
		_diff_box.add_child(vbox)

func _clear(vbox: VBoxContainer) -> void:
	for child in vbox.get_children():
		vbox.remove_child(child)
		child.free()

func _make_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 22)
	return lbl

func _refresh_char() -> void:
	_char_label.text = "← %s →" % CHAR_NAMES[_char_index]
	_build_lists()
	_highlight()
	_build_lists()
	_highlight()

# ═══ 高亮 ═══

func _highlight() -> void:
	_dim_all(_stage_box)
	_dim_all(_phase_box)
	_dim_diff()
	
	match _section:
		Section.STAGE:
			_highlight_one(_stage_box, _stage_index)
		Section.PHASE:
			_highlight_one(_phase_box, _phase_index)
			_build_diff_list()
			_dim_diff()
		Section.DIFF:
			_highlight_diff(_diff_index)

func _dim_all(vbox: VBoxContainer) -> void:
	for child in vbox.get_children():
		child.modulate = Color(0.3, 0.3, 0.3)

func _highlight_one(vbox: VBoxContainer, idx: int) -> void:
	var children := vbox.get_children()
	for i in children.size():
		children[i].modulate = Color.WHITE if i == idx else Color(0.4, 0.4, 0.4)

func _dim_diff() -> void:
	for item in _diff_box.get_children():
		for child in item.get_children():
			child.modulate = Color(0.3, 0.3, 0.3)

func _highlight_diff(idx: int) -> void:
	var items := _diff_box.get_children()
	for i in items.size():
		var vbox := items[i]
		for child in vbox.get_children():
			child.modulate = Color.WHITE if i == idx else Color(0.4, 0.4, 0.4)

# ═══ 索引 ═══

func _max_idx() -> int:
	match _section:
		Section.STAGE: return _stages.size() - 1
		Section.PHASE: return _phases.size() - 1
		Section.DIFF:
			if _phase_index >= _phases.size(): return -1
			var names = _phases[_phase_index].get("spell_names")
			return names.size() - 1 if names is Array else -1
	return 0

func _get_idx() -> int:
	match _section:
		Section.STAGE: return _stage_index
		Section.PHASE: return _phase_index
		Section.DIFF:  return _diff_index
	return 0

func _set_idx(v: int) -> void:
	match _section:
		Section.STAGE: _stage_index = v; _change_stage(v)
		Section.PHASE: _phase_index = v; _build_diff_list(); _dim_diff()
		Section.DIFF:  _diff_index = v

# ═══ 输入 ═══

func _input(event: InputEvent) -> void:
	if not _ready: return
	
	if event.is_action_pressed("ui_cancel"):
		if _section == Section.STAGE:
			_on_leave()
		else:
			_section -= 1
			_highlight()
		get_viewport().set_input_as_handled()
		return
	
	if event.is_action_pressed("ui_left"):
		_char_index = wrapi(_char_index - 1, 0, CHAR_NAMES.size())
		_refresh_char()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_right"):
		_char_index = wrapi(_char_index + 1, 0, CHAR_NAMES.size())
		_refresh_char()
		get_viewport().set_input_as_handled()
	
	var maxi := _max_idx()
	if maxi < 0: return
	
	if event.is_action_pressed("ui_up"):
		_set_idx(wrapi(_get_idx() - 1, 0, maxi + 1))
		_highlight()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_down"):
		_set_idx(wrapi(_get_idx() + 1, 0, maxi + 1))
		_highlight()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		if _section == Section.DIFF:
			_start_practice()
		elif _section == Section.PHASE:
			_section = Section.DIFF
			_build_diff_list()
			_highlight()
		else:
			_section += 1
			_highlight()
		get_viewport().set_input_as_handled()

func _start_practice() -> void:
	if _phases.is_empty(): return
	var phase = _phases[_phase_index]
	if not phase: return
	var stage_num: int = _stages[_stage_index].get("num", 1)
	var names = phase.get("spell_names")
	var pname: String = names[_diff_index] if names is Array else ""
	print("练习: ", pname, " 角色:", CHAR_NAMES[_char_index], " Stage:", stage_num, " Phase:", _phase_index + 1, " 难度:", DIFF_NAMES[_diff_index])
	_on_leave()
