# SpellPracticeMenu.gd
extends Control

const MenuScreenClass = preload("res://scripts/scenes/ui/menu_screen.gd")

@onready var _stage_list: VBoxContainer = $StagePanel/VBoxContainer
@onready var _phase_list: VBoxContainer = $PhasePanel/VBoxContainer
@onready var _diff_list: VBoxContainer = $DiffPanel/VBoxContainer
@onready var _char_label: Label = $CharPanel/CharName
@onready var _title_label: Label = $Title

enum Section { STAGE, PHASE, DIFF }
var _section: int = Section.STAGE
var _stage_index: int = 0
var _phase_index: int = 0
var _diff_index: int = 1  # Normal 默认
var _char_index: int = 0  # 0=Reimu 1=Marisa

const DIFF_NAMES := ["Easy", "Normal", "Hard", "Lunatic"]
const CHAR_NAMES := ["博丽灵梦", "雾雨魔理沙"]
var _stages: Array = []       # [{name, phases[]}]
var _phases: Array = []       # PhaseData[]
var _ready: bool = false


func _on_enter() -> void:
	_build_data()
	_build_ui()
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.3)
	tw.tween_callback(func(): _ready = true)

func _on_leave() -> void:
	_ready = false
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.2)
	tw.tween_callback(queue_free)

# ═══ 数据准备 ═══

func _build_data() -> void:
	# TODO: 从实际关卡数据收集
	# 暂时硬编码测试
	_stages = [
		{name="Stage 1", phases=_get_test_phases()},
		{name="Stage 2", phases=[]},
	]
	_change_stage(0)

func _get_test_phases() -> Array:
	var p1 := PhaseData.new()
	p1.name = "非符1"
	p1.spell_id = 0
	var p2 := PhaseData.new()
	p2.name = "测试「First」"
	p2.spell_id = 1
	var p3 := PhaseData.new()
	p3.name = "测试「Second」"
	p3.spell_id = 2
	return [p1, p2, p3]

# ═══ UI ═══

func _build_ui() -> void:
	_refresh_all()

func _refresh_all() -> void:
	_refresh_stage()
	_refresh_phase()
	_refresh_diff()
	_refresh_char()

func _change_stage(idx: int) -> void:
	_stage_index = idx
	if idx < _stages.size():
		_phases = _stages[idx].phases
	else:
		_phases = []
	_phase_index = 0
	_refresh_phase()

func _refresh_stage() -> void:
	_clear_list(_stage_list)
	for i in _stages.size():
		var lbl := _make_label(_stages[i].name, i == _stage_index)
		_stage_list.add_child(lbl)

func _refresh_phase() -> void:
	_clear_list(_phase_list)
	for i in _phases.size():
		var p = _phases[i]
		var nm: String = p.get("name") if p.get("name") != "" else "非符 %d" % (i+1)
		var lbl := _make_label(nm, i == _phase_index)
		_phase_list.add_child(lbl)

func _refresh_diff() -> void:
	_clear_list(_diff_list)
	for i in DIFF_NAMES.size():
		var lbl := _make_label(DIFF_NAMES[i], i == _diff_index)
		_diff_list.add_child(lbl)

func _refresh_char() -> void:
	_char_label.text = "← %s →" % CHAR_NAMES[_char_index]

func _clear_list(vbox: VBoxContainer) -> void:
	for child in vbox.get_children():
		child.queue_free()

func _make_label(text: String, selected: bool) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 24)
	lbl.modulate = Color.WHITE if selected else Color(0.4, 0.4, 0.4)
	return lbl

# ═══ 输入 ═══

func _input(event: InputEvent) -> void:
	if not _ready: return
	
	if event.is_action_pressed("ui_cancel"):
		get_parent().emit_signal("finished", {})
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
	
	match _section:
		Section.STAGE:
			if event.is_action_pressed("ui_up"):
				_stage_index = wrapi(_stage_index - 1, 0, _stages.size())
				_change_stage(_stage_index)
				_refresh_stage()
				get_viewport().set_input_as_handled()
			elif event.is_action_pressed("ui_down"):
				_stage_index = wrapi(_stage_index + 1, 0, _stages.size())
				_change_stage(_stage_index)
				_refresh_stage()
				get_viewport().set_input_as_handled()
			elif event.is_action_pressed("ui_accept"):
				if _phases.is_empty(): return
				_section = Section.PHASE
				_refresh_all()
				get_viewport().set_input_as_handled()
		
		Section.PHASE:
			if event.is_action_pressed("ui_up"):
				_phase_index = wrapi(_phase_index - 1, 0, _phases.size())
				_refresh_phase()
				get_viewport().set_input_as_handled()
			elif event.is_action_pressed("ui_down"):
				_phase_index = wrapi(_phase_index + 1, 0, _phases.size())
				_refresh_phase()
				get_viewport().set_input_as_handled()
			elif event.is_action_pressed("ui_accept"):
				_section = Section.DIFF
				_refresh_all()
				get_viewport().set_input_as_handled()
		
		Section.DIFF:
			if event.is_action_pressed("ui_up"):
				_diff_index = wrapi(_diff_index - 1, 0, DIFF_NAMES.size())
				_refresh_diff()
				get_viewport().set_input_as_handled()
			elif event.is_action_pressed("ui_down"):
				_diff_index = wrapi(_diff_index + 1, 0, DIFF_NAMES.size())
				_refresh_diff()
				get_viewport().set_input_as_handled()
			elif event.is_action_pressed("ui_accept"):
				_start_practice()
				get_viewport().set_input_as_handled()

func _start_practice() -> void:
	if _phases.is_empty(): return
	var phase = _phases[_phase_index]
	if not phase: return
	var pname: String = phase.get("name") if phase.has_method("get") else str(phase)
	print("练习开始: ", pname, " 难度:", DIFF_NAMES[_diff_index], " 角色:", CHAR_NAMES[_char_index])
