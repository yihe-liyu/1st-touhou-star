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

const DIFF_NAMES = SpellRecord.DIFF_NAMES
const CHAR_NAMES = SpellRecord.CHAR_NAMES
var _stages: Array[int] = []       # 有记录的关卡号列表
var _phases: Array = []             # [{type, num, names[]}]
var _phase_spell_nums: Array[int] = []
var _phase_non_nums: Array[int] = []


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

# ═══ 从 RecordBook 生成菜单 ═══

func _build_data() -> void:
	var book: Resource = GameState.spell_book
	var all_recs: Array = book.records
	
	# 收集该角色有记录的关卡
	var stage_set: Dictionary = {}
	for r in all_recs:
		if r.get("character") != _char_index:
			continue
		var st: int = r.get("stage")
		if not stage_set.has(st):
			stage_set[st] = true
	
	_stages.clear()
	for st in stage_set.keys():
		_stages.append(st)
	_stages.sort()
	
	if _stages.is_empty():
		return
	
	_stage_index = 0
	_change_stage(0)

# ═══ 切换关卡 ═══

func _change_stage(idx: int) -> void:
	_stage_index = idx
	_phases.clear()
	_phase_spell_nums.clear()
	_phase_non_nums.clear()
	
	if _stages.is_empty(): return
	var st_num: int = _stages[idx]
	var book: Resource = GameState.spell_book
	
	# 收集该关卡有记录的 phase
	# 结构: { (phase_type, phase_number): { diff → record } }
	var phase_map: Dictionary = {}
	for r in book.records:
		if r.get("character") != _char_index or r.get("stage") != st_num:
			continue
		var pt: int = r.get("phase_type")
		var pn: int = r.get("phase_number")
		var key = "%d_%d" % [pt, pn]
		if not phase_map.has(key):
			phase_map[key] = {type=pt, num=pn, diffs={}}
		phase_map[key]["diffs"][r.get("difficulty")] = r
	
	# 按类型和编号排序
	var keys := phase_map.keys()
	keys.sort_custom(func(a, b):
		var ra = phase_map[a]["diffs"].values()[0]
		var rb = phase_map[b]["diffs"].values()[0]
		return ra.get("phase_order") < rb.get("phase_order")
	)
	
	var spell_c := 0; var non_c := 0
	for key in keys:
		var info = phase_map[key]
		var pt: int = info.type
		var pn: int = info.num
		if pt == SpellRecord.PhaseType.NONSPELL:
			non_c += 1
			_phase_spell_nums.append(0)
			_phase_non_nums.append(non_c)
			_phases.append({type=pt, num=pn, diffs=info.diffs})
		else:
			spell_c += 1
			_phase_spell_nums.append(spell_c)
			_phase_non_nums.append(0)
			_phases.append({type=pt, num=pn, diffs=info.diffs})
	
	_phase_index = 0
	_build_phase_list()

# ═══ 构建列表 ═══

func _build_lists() -> void:
	_clear(_stage_box)
	if _stages.is_empty():
		var lbl := Label.new()
		lbl.text = "No records"
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 20)
		_stage_box.add_child(lbl)
		return
	
	var book: Resource = GameState.spell_book
	for st in _stages:
		var lbl := _make_label("Stage %d" % st)
		var recs: Array = book.get_by_stage(_char_index, st)
		var cap := 0; var att := 0
		for r in recs:
			cap += r.get("captures")
			att += r.get("attempts")
		if att > 0:
			lbl.text += "  %d/%d" % [cap, att]
		_stage_box.add_child(lbl)
	_build_phase_list()

func _build_phase_list() -> void:
	_clear(_phase_box)
	var book: Resource = GameState.spell_book
	var st_num: int = _stages[_stage_index] if _stage_index < _stages.size() else 0
	
	for i in _phases.size():
		var info = _phases[i]
		var suffix := ""
		var cap := 0; var att := 0
		for diff in info.diffs.keys():
			var r = info.diffs[diff]
			cap += r.get("captures")
			att += r.get("attempts")
		if att > 0:
			suffix = "  %d/%d" % [cap, att]
		
		if info.type == SpellRecord.PhaseType.NONSPELL:
			_phase_box.add_child(_make_label("非符%d%s" % [_phase_non_nums[i], suffix]))
		else:
			_phase_box.add_child(_make_label("符卡%d%s" % [_phase_spell_nums[i], suffix]))

func _build_diff_list() -> void:
	_clear(_diff_box)
	if _phase_index >= _phases.size(): return
	var info = _phases[_phase_index]
	
	for d in range(SpellRecord.DIFF_NAMES.size()):
		if not info.diffs.has(d):
			continue  # 没有这个难度的记录，跳过
		
		var r = info.diffs[d]
		var vbox := VBoxContainer.new()
		var nl := Label.new()
		var name_str: String = r.get("spell_name") if r.get("spell_name") != "" else "-"
		nl.text = name_str
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nl.add_theme_font_size_override("font_size", 26)
		vbox.add_child(nl)
		
		var hl := Label.new()
		var uid: int = r.get("spell_uid")
		var uid_str := ""
		if uid > 0:
			uid_str = "No.%03d  " % uid
		var cap_str := "  %d/%d" % [r.get("captures"), r.get("attempts")]
		hl.text = uid_str + DIFF_NAMES[d] + cap_str
		hl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		hl.add_theme_font_size_override("font_size", 18)
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
	lbl.add_theme_font_size_override("font_size", 28)
	return lbl

# ═══ 高亮 ═══

func _highlight() -> void:
	_dim_all(_stage_box)
	_dim_all(_phase_box)
	_dim_diff()
	
	match _section:
		Section.STAGE:
			_highlight_one(_stage_box, _stage_index)
			_clear(_diff_box)
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
		for child in items[i].get_children():
			child.modulate = Color.WHITE if i == idx else Color(0.4, 0.4, 0.4)

# ═══ 索引 ═══

func _max_idx() -> int:
	match _section:
		Section.STAGE: return _stages.size() - 1
		Section.PHASE: return _phases.size() - 1
		Section.DIFF:
			if _phase_index >= _phases.size(): return -1
			var info = _phases[_phase_index]
			return info.diffs.keys().size() - 1
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

# ═══ 刷新角色 ═══

func _refresh_char() -> void:
	_char_label.text = "← %s →" % CHAR_NAMES[_char_index]
	_build_data()
	_build_lists()
	_highlight()

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
	var info = _phases[_phase_index]
	if info.diffs.is_empty(): return
	var diff_keys: Array = info.diffs.keys()
	diff_keys.sort()
	var diff: int = diff_keys[_diff_index]
	var r = info.diffs[diff]
	var pname: String = r.get("spell_name")
	print("练习: ", pname, " 角色:", CHAR_NAMES[_char_index], " 难度:", DIFF_NAMES[diff])
	_on_leave()
