# SpellPracticeMenu.gd
extends MenuScreen

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
var _stages: Array[int] = []
var _phases: Array = []
var _phase_spell_nums: Array[int] = []
var _phase_non_nums: Array[int] = []


func _on_enter() -> void:
	_build_data()
	_char_label.text = "← %s →" % CHAR_NAMES[_char_index]
	_build_lists()
	_highlight()
	# 全不透明，无入口动画
	modulate.a = 1.0
	_ready = true

func _on_leave() -> void:
	_ready = false
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.2)
	tw.tween_callback(queue_free)

# ═══ 从 RecordBook 生成 ═══

func _build_data() -> void:
	var book: SpellRecordBook = GameState.spell_book
	var stage_set: Dictionary = {}
	for r in book.records:
		if r.character != _char_index: continue
		stage_set[r.stage] = true
	
	_stages.clear()
	for st in stage_set.keys():
		_stages.append(st)
	_stages.sort()
	
	_phases.clear()
	_phase_spell_nums.clear()
	_phase_non_nums.clear()
	
	if not _stages.is_empty():
		_stage_index = 0
		_change_stage(0)

func _change_stage(idx: int) -> void:
	_stage_index = idx
	_phases.clear()
	_phase_spell_nums.clear()
	_phase_non_nums.clear()
	
	if _stages.is_empty(): return
	var st_num: int = _stages[idx]
	var book: SpellRecordBook = GameState.spell_book
	
	var phase_map: Dictionary = {}
	for r in book.records:
		if r.character != _char_index or r.stage != st_num: continue
		var key = "%d_%d" % [r.phase_type, r.phase_number]
		if not phase_map.has(key):
			phase_map[key] = {type=r.phase_type, num=r.phase_number, diffs={}}
		phase_map[key]["diffs"][r.difficulty] = r
	
	var keys := phase_map.keys()
	keys.sort_custom(func(a, b):
		var ra = phase_map[a]["diffs"].values()[0]
		var rb = phase_map[b]["diffs"].values()[0]
		return ra.phase_order < rb.phase_order
	)
	
	var spell_c := 0; var non_c := 0
	for key in keys:
		var info = phase_map[key]
		if info.type == SpellRecord.PhaseType.NONSPELL:
			non_c += 1
			_phase_spell_nums.append(0)
			_phase_non_nums.append(non_c)
		else:
			spell_c += 1
			_phase_spell_nums.append(spell_c)
			_phase_non_nums.append(0)
		_phases.append(info)
	
	_phase_index = 0

# ═══ 构建列表 ═══

func _build_lists() -> void:
	_clear(_stage_box)
	if _stages.is_empty():
		var lbl := Label.new()
		lbl.text = "No records"
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 28)
		_stage_box.add_child(lbl)
		_clear(_phase_box)
		return
	
	for st in _stages:
		_stage_box.add_child(_make_label("Stage %d" % st))
	_build_phase_list()

func _build_phase_list() -> void:
	_clear(_phase_box)
	
	for i in _phases.size():
		var info = _phases[i]
		var name_str := ""
		if info.type == SpellRecord.PhaseType.NONSPELL:
			name_str = "非符%d" % _phase_non_nums[i]
		else:
			name_str = "符卡%d" % _phase_spell_nums[i]
		
		_phase_box.add_child(_make_label(name_str))

func _build_diff_list() -> void:
	_clear(_diff_box)
	if _phase_index >= _phases.size(): return
	var info = _phases[_phase_index]
	
	for d in range(SpellRecord.DIFF_NAMES.size()):
		if not info.diffs.has(d): continue
		
		var r = info.diffs[d]
		var vbox := VBoxContainer.new()
		var nl := Label.new()
		nl.text = r.spell_name if r.spell_name != "" else "-"
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nl.add_theme_font_size_override("font_size", 30)
		vbox.add_child(nl)
		
		# 小字行: No.001  Normal  ──右靠──  0/0
		var hrow := HBoxContainer.new()
		hrow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var hl := Label.new()
		var uid_str := ""
		if r.spell_uid > 0:
			uid_str = "No.%03d  " % r.spell_uid
		hl.text = uid_str + DIFF_NAMES[d]
		hl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		hl.add_theme_font_size_override("font_size", 22)
		hl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		hl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hl.size_flags_stretch_ratio = 1.0
		hrow.add_child(hl)
		
		var stat_str := "%02d/%02d" % [r.practice_captures, r.practice_attempts]
		var sl := Label.new()
		sl.text = stat_str
		sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		sl.add_theme_font_size_override("font_size", 22)
		sl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		hrow.add_child(sl)
		
		vbox.add_child(hrow)
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
	_dim_all_vbox(_stage_box)
	_dim_all_vbox(_phase_box)
	_dim_diff()
	
	match _section:
		Section.STAGE:
			_highlight_one_vbox(_stage_box, _stage_index)
			_clear(_diff_box)
		Section.PHASE:
			_highlight_one_vbox(_phase_box, _phase_index)
			_build_diff_list()
			_dim_diff()
		Section.DIFF:
			_highlight_diff(_diff_index)

func _dim_all_vbox(vbox: VBoxContainer) -> void:
	for child in vbox.get_children():
		child.modulate = Color(0.3, 0.3, 0.3)

func _highlight_one_vbox(vbox: VBoxContainer, idx: int) -> void:
	var children := vbox.get_children()
	for i in children.size():
		children[i].modulate = Color.WHITE if i == idx else Color(0.4, 0.4, 0.4)

func _dim_diff() -> void:
	for vbox in _diff_box.get_children():
		for child in vbox.get_children():
			if child is HBoxContainer:
				for sub in child.get_children():
					sub.modulate = Color(0.3, 0.3, 0.3)
			else:
				child.modulate = Color(0.3, 0.3, 0.3)

func _highlight_diff(idx: int) -> void:
	var items := _diff_box.get_children()
	for i in items.size():
		var vbox := items[i]
		var dim := Color(0.3, 0.3, 0.3) if i != idx else Color(0.4, 0.4, 0.4)
		var bright := Color.WHITE
		for child in vbox.get_children():
			if child is HBoxContainer:
				for sub in child.get_children():
					sub.modulate = bright if i == idx else dim
			else:
				child.modulate = bright if i == idx else dim

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

func _refresh_char() -> void:
	_char_label.text = "← %s →" % CHAR_NAMES[_char_index]
	_section = Section.STAGE
	_stage_index = 0
	_phase_index = 0
	_diff_index = 0
	_build_data()
	_build_lists()
	_highlight()

# ═══ 输入 ═══

func _input(event: InputEvent) -> void:
	if not _ready: return
	
	if event.is_action_pressed("ui_cancel"):
		AudioManager.play_sfx(preload("res://assets/Sound/cancel.wav"))
		if _section == Section.STAGE: leave()
		else: _section -= 1; _highlight()
		get_viewport().set_input_as_handled()
		return
	
	if event.is_action_pressed("ui_left"):
		AudioManager.play_sfx(preload("res://assets/Sound/select.wav"))
		_char_index = wrapi(_char_index - 1, 0, CHAR_NAMES.size())
		_refresh_char()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_right"):
		AudioManager.play_sfx(preload("res://assets/Sound/select.wav"))
		_char_index = wrapi(_char_index + 1, 0, CHAR_NAMES.size())
		_refresh_char()
		get_viewport().set_input_as_handled()
	
	var mx := _max_idx()
	if mx < 0: return
	
	if event.is_action_pressed("ui_up"):
		AudioManager.play_sfx(preload("res://assets/Sound/select.wav"))
		_set_idx(wrapi(_get_idx() - 1, 0, mx + 1))
		_highlight()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_down"):
		AudioManager.play_sfx(preload("res://assets/Sound/select.wav"))
		_set_idx(wrapi(_get_idx() + 1, 0, mx + 1))
		_highlight()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		AudioManager.play_sfx(preload("res://assets/Sound/ok.wav"))
		if _section == Section.DIFF: _start_practice()
		elif _section == Section.PHASE:
			_section = Section.DIFF
			_diff_index = 0
			_build_diff_list()
			_highlight()
		else: _section += 1; _highlight()
		get_viewport().set_input_as_handled()

func _start_practice() -> void:
	if _phases.is_empty(): return
	var info = _phases[_phase_index]
	if info.diffs.is_empty(): return
	var diff_keys: Array = info.diffs.keys()
	diff_keys.sort()
	var diff: int = diff_keys[_diff_index]
	var r = info.diffs[diff]
	var st_num := _stages[_stage_index] if _stage_index < _stages.size() else 0
	
	var result := _find_practice_target(st_num, info.type, info.num)
	if result.is_empty():
		print("找不到 BossData/PhaseData")
		_on_leave()
		return
	
	# 设置练习模式
	GameState.selected_difficulty = diff
	GameState.selected_character = _char_index
	
	# 找到目标 phase 在 BossData 中的索引
	var boss_data: BossData = result["boss_data"]
	var phase_idx: int = 0
	var spell_c := 0; var non_c := 0
	for i in boss_data.phases.size():
		var phase = boss_data.phases[i]
		if phase.uid != 0:
			spell_c += 1
			if info.type == SpellRecord.PhaseType.SPELL and spell_c == info.num:
				phase_idx = i
				break
		else:
			non_c += 1
			if info.type == SpellRecord.PhaseType.NONSPELL and non_c == info.num:
				phase_idx = i
				break
	
	print("练习: ", r.spell_name, " 难度: ", DIFF_NAMES[diff])
	GameState.start_practice(boss_data, phase_idx, st_num)
	AudioManager.stop_bgm()
	_on_leave()
	GameManager.change_scene("res://scenes/game_scene.tscn")

func _find_practice_target(stage: int, phase_type: int, phase_num: int) -> Dictionary:
	var dir := DirAccess.open("res://data/stages/")
	if not dir: return {}
	dir.list_dir_begin()
	var fn := dir.get_next()
	while fn != "":
		if fn.ends_with(".tres"):
			var sd: StageData = ResourceLoader.load("res://data/stages/" + fn)
			if sd and sd.stage_id == stage and sd.boss_data:
				return {"boss_data": sd.boss_data, "phase_data": _match_phase(sd.boss_data, phase_type, phase_num)}
		fn = dir.get_next()
	return {}

func _match_phase(boss_data: BossData, phase_type: int, phase_num: int) -> PhaseData:
	var spell_c := 0; var non_c := 0
	for phase in boss_data.phases:
		if phase.uid != 0:
			spell_c += 1
			if phase_type == SpellRecord.PhaseType.SPELL and spell_c == phase_num:
				return phase
		else:
			non_c += 1
			if phase_type == SpellRecord.PhaseType.NONSPELL and non_c == phase_num:
				return phase
	return null
