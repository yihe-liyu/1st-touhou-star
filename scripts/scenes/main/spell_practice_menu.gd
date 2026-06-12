# SpellPracticeMenu.gd
extends Control

@onready var _vbox: VBoxContainer = $VBoxContainer
@onready var _title_label: Label = $Title
@onready var _char_label: Label = $CharPanel/CharName

enum Section { STAGE, PHASE, DIFF }
var _section: int = Section.STAGE
var _stage_index: int = 0
var _phase_index: int = 0
var _diff_index: int = 1
var _char_index: int = 0
var _ready: bool = false
var _tween: Tween

const DIFF_NAMES := ["Easy", "Normal", "Hard", "Lunatic"]
const CHAR_NAMES := ["博丽灵梦", "雾雨魔理沙"]
var _stages: Array = []       # [{name, phases[]}]
var _phases: Array = []       # PhaseData[]


func _on_enter() -> void:
	_build_data()
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.3)
	tw.tween_callback(func(): _ready = true; _switch_to(Section.STAGE))

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
	_stage_index = clampi(idx, 0, _stages.size() - 1)
	_phases = _stages[_stage_index].get("phases", [])
	_phase_index = 0

# ═══ 切换 section ═══

func _switch_to(sec: int) -> void:
	_section = sec
	_fade_out_list()
	await get_tree().create_timer(0.15).timeout
	_rebuild_list()
	_fade_in_list()
	_refresh_char()

func _fade_out_list() -> void:
	if _tween: _tween.kill()
	_tween = create_tween()
	_tween.tween_property(_vbox, "modulate:a", 0.0, 0.12)

func _fade_in_list() -> void:
	if _tween: _tween.kill()
	_tween = create_tween()
	_tween.tween_property(_vbox, "modulate:a", 1.0, 0.15)

func _rebuild_list() -> void:
	for child in _vbox.get_children():
		child.queue_free()
	
	match _section:
		Section.STAGE:
			_title_label.text = "Select Stage"
			for i in _stages.size():
				_vbox.add_child(_make_label(_stages[i].name, i == _stage_index))
		
		Section.PHASE:
			_title_label.text = "Select Phase"
			for i in _phases.size():
				var nm: String = _phases[i].get("name")
				if nm == "": nm = "非符 %d" % (i + 1)
				_vbox.add_child(_make_label(nm, i == _phase_index))
		
		Section.DIFF:
			_title_label.text = "Select Difficulty"
			for i in DIFF_NAMES.size():
				_vbox.add_child(_make_label(DIFF_NAMES[i], i == _diff_index))

func _refresh_char() -> void:
	_char_label.text = "← %s →" % CHAR_NAMES[_char_index]

func _make_label(text: String, selected: bool) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 26)
	lbl.modulate = Color.WHITE if selected else Color(0.4, 0.4, 0.4)
	return lbl

# ═══ 刷新选中 ═══

func _refresh_selection() -> void:
	var children := _vbox.get_children()
	var idx: int
	match _section:
		Section.STAGE: idx = _stage_index
		Section.PHASE: idx = _phase_index
		Section.DIFF:  idx = _diff_index
	for i in children.size():
		children[i].modulate = Color.WHITE if i == idx else Color(0.4, 0.4, 0.4)

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
			_switch_to(_section - 1)
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
		var idx := _get_idx()
		_set_idx(wrapi(idx - 1, 0, maxi + 1))
		_refresh_selection()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_down"):
		var idx := _get_idx()
		_set_idx(wrapi(idx + 1, 0, maxi + 1))
		_refresh_selection()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		if _section == Section.DIFF:
			_start_practice()
		else:
			if _max_idx() >= 0:
				_switch_to(_section + 1)
		get_viewport().set_input_as_handled()

func _start_practice() -> void:
	if _phases.is_empty(): return
	var phase = _phases[_phase_index]
	if not phase: return
	var pname: String = phase.get("name") if phase.has_method("get") else str(phase)
	print("练习: ", pname, " 难度:", DIFF_NAMES[_diff_index], " 角色:", CHAR_NAMES[_char_index])
	_on_leave()
