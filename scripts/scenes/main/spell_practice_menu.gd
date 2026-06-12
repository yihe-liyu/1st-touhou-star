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
var _diff_index: int = 1
var _char_index: int = 0
var _ready: bool = false

const DIFF_NAMES := ["Easy", "Normal", "Hard", "Lunatic"]
const CHAR_NAMES := ["博丽灵梦", "雾雨魔理沙"]
var _stages: Array = []
var _phases: Array = []


func _on_enter() -> void:
	_build_data()
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.3)
	tw.tween_callback(func(): _ready = true; _build_lists(); _highlight())

func _on_leave() -> void:
	_ready = false
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.2)
	tw.tween_callback(queue_free)

# ═══ 数据 ═══

func _build_data() -> void:
	_stages = [
		{name="Stage 1", phases=_get_test_phases()},
		{name="Stage 2", phases=[]},
	]
	_stage_index = 0
	_change_stage(0)

func _get_test_phases() -> Array:
	var p1 := PhaseData.new(); p1.name = "非符1"; p1.spell_id = 0
	var p2 := PhaseData.new(); p2.name = "测试「First」"; p2.spell_id = 1
	var p3 := PhaseData.new(); p3.name = "测试「Second」"; p3.spell_id = 2
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
		_stage_box.add_child(_make_label(s.name))
	
	_build_phase_list()
	
	_clear(_diff_box)
	for d in DIFF_NAMES:
		_diff_box.add_child(_make_label(d))
	
	_refresh_char()

func _build_phase_list() -> void:
	_clear(_phase_box)
	for p in _phases:
		var nm: String = p.get("name")
		if nm == "": nm = "非符"
		_phase_box.add_child(_make_label(nm))

func _clear(vbox: VBoxContainer) -> void:
	for child in vbox.get_children():
		child.queue_free()

func _make_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 22)
	return lbl

func _refresh_char() -> void:
	_char_label.text = "← %s →" % CHAR_NAMES[_char_index]

# ═══ 高亮 ═══

func _highlight() -> void:
	_dim_all(_stage_box)
	_dim_all(_phase_box)
	_dim_all(_diff_box)
	
	match _section:
		Section.STAGE:
			_highlight_one(_stage_box, _stage_index)
		Section.PHASE:
			_highlight_one(_phase_box, _phase_index)
		Section.DIFF:
			_highlight_one(_diff_box, _diff_index)

func _dim_all(vbox: VBoxContainer) -> void:
	for child in vbox.get_children():
		child.modulate = Color(0.3, 0.3, 0.3)

func _highlight_one(vbox: VBoxContainer, idx: int) -> void:
	var children := vbox.get_children()
	for i in children.size():
		children[i].modulate = Color.WHITE if i == idx else Color(0.4, 0.4, 0.4)

func _get_box() -> VBoxContainer:
	match _section:
		Section.STAGE: return _stage_box
		Section.PHASE: return _phase_box
	return _diff_box

func _max_idx() -> int:
	match _section:
		Section.STAGE: return _stages.size() - 1
		Section.PHASE: return _phases.size() - 1
		Section.DIFF:  return DIFF_NAMES.size() - 1
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
		Section.PHASE: _phase_index = v
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
		elif _max_idx() >= 0:
			_section += 1
			_highlight()
		get_viewport().set_input_as_handled()

func _start_practice() -> void:
	if _phases.is_empty(): return
	var phase = _phases[_phase_index]
	if not phase: return
	var pname: String = phase.get("name") if phase.has_method("get") else str(phase)
	print("练习: ", pname, " 难度:", DIFF_NAMES[_diff_index], " 角色:", CHAR_NAMES[_char_index])
	_on_leave()
