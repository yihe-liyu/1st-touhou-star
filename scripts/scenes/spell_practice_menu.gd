# SpellPracticeMenu.gd — 符卡练习（CardRegistry 驱动）
extends BasePage

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
var _input_ready: bool = false

const DIFF_NAMES = SpellRecord.DIFF_NAMES
const DIFF_VALUES = SpellRecord.DIFF_VALUES
const CHAR_NAMES = SpellRecord.CHAR_NAMES


func diff_name(v: int) -> String:
	var idx := DIFF_VALUES.find(v)
	return DIFF_NAMES[idx] if idx >= 0 else "?"


var _stages: Array[int] = []
# 每个 phase: {card: CardDef, diffs: {diff: SpellRecord}}
var _phases: Array[Dictionary] = []
var _pulse_tween: Tween

var _registry: CardRegistry


# ═══ 生命周期 ═══

func _on_enter() -> void:
	modulate.a = 0.0
	if ResourceLoader.exists("res://data/registry/spell_registry.tres"):
		_registry = ResourceLoader.load("res://data/registry/spell_registry.tres")
	else:
		_registry = null
	_char_label.text = "← %s →" % CHAR_NAMES[_char_index]
	_build_data()
	_build_lists()
	_highlight()

	var overlay: ColorRect = $"Overlay"
	overlay.color = Color(0, 0, 0, 0.5)

	var tw := create_tween()
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 1.0, 0.35)
	tw.tween_callback(func(): _input_ready = true)


func _on_leave() -> void:
	_input_ready = false
	_stop_pulse()

	var tw := create_tween()
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 0.0, 0.12)
	tw.tween_callback(queue_free)


# ═══ 从 CardRegistry 生成 ═══

func _build_data() -> void:
	_stages.clear()
	_phases.clear()

	if not _registry or _registry.cards.is_empty():
		_stages = []
		return

	_stages = _registry.get_stage_ids()

	if not _stages.is_empty():
		_stage_index = 0
		_change_stage(0)


func _change_stage(idx: int) -> void:
	_stage_index = idx
	_phases.clear()

	if _stages.is_empty() or not _registry:
		return

	var st_num: int = _stages[idx]
	var cards := _registry.get_by_stage(st_num)
	var book: SpellRecordBook = GameState.spell_book

	var spell_seq := 0
	var non_seq := 0

	for card in cards:
		# 角色过滤
		if card.character >= 0 and card.character != _char_index:
			continue

		var is_spell := card.phase_data and card.phase_data.uid != 0
		if not card.phase_data:
			push_warning("SpellPractice: CardDef uid=%d name=\"%s\" 缺少 phase_data" % [card.uid, card.name])
		if not card.boss_scene:
			push_warning("SpellPractice: CardDef uid=%d name=\"%s\" 缺少 boss_scene" % [card.uid, card.name])
		if not card.background_scene:
			push_warning("SpellPractice: CardDef uid=%d name=\"%s\" 缺少 background_scene （练习背景将为空）" % [card.uid, card.name])
		if card.order <= 0:
			push_warning("SpellPractice: CardDef uid=%d name=\"%s\" order 为 %d，应为 >0" % [card.uid, card.name, card.order])

		if is_spell:
			spell_seq += 1
		else:
			non_seq += 1

		var label := "符卡%d" % spell_seq if is_spell else "非符%d" % non_seq

		var info := {card = card, diffs = {}, label = label}
		var diff_keys := DIFF_VALUES if card.difficulty < 0 else [card.difficulty]

		for d in diff_keys:
			var rec: SpellRecord = GameState.ensure_record(card.uid, _char_index, d,
				st_num, card.name, card.order)
			info["diffs"][d] = rec

		_phases.append(info)

	_phase_index = 0


# ═══ 构建列表 ═══

func _build_lists() -> void:
	_clear(_stage_box)
	if _stages.is_empty():
		var lbl := Label.new()
		lbl.text = "No cards registered"
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

	for info in _phases:
		_phase_box.add_child(_make_label(info["label"]))


func _build_diff_list() -> void:
	_clear(_diff_box)
	if _phase_index >= _phases.size():
		return

	var info = _phases[_phase_index]
	var diffs: Array = info["diffs"].keys()
	diffs.sort()

	for d in diffs:
		var r: SpellRecord = info["diffs"][d]
		var vbox := VBoxContainer.new()
		var nl := Label.new()
		nl.text = r.spell_name if r.spell_name != "" else "-"
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nl.add_theme_font_size_override("font_size", 30)
		vbox.add_child(nl)

		var hrow := HBoxContainer.new()
		hrow.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var hl := Label.new()
		var uid_str := ""
		if r.uid > 0:
			uid_str = "No.%03d  " % r.uid
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
	_stop_pulse()
	_dim_all_vbox(_stage_box)
	_dim_all_vbox(_phase_box)
	_dim_diff()

	match _section:
		Section.STAGE:
			_highlight_one_vbox(_stage_box, _stage_index)
			_pulse_on_vbox(_stage_box, _stage_index)
			_clear(_diff_box)
		Section.PHASE:
			_highlight_one_vbox(_phase_box, _phase_index)
			_pulse_on_vbox(_phase_box, _phase_index)
			_build_diff_list()
			_dim_diff()
		Section.DIFF:
			_highlight_diff(_diff_index)
			_pulse_on_diff(_diff_index)


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


func _pulse_on_vbox(vbox: VBoxContainer, idx: int) -> void:
	var children := vbox.get_children()
	if idx < children.size():
		_start_pulse(children[idx])


func _pulse_on_diff(idx: int) -> void:
	var items := _diff_box.get_children()
	if idx < items.size():
		_start_pulse(items[idx])


# ═══ 脉冲 ═══

func _start_pulse(item: Control) -> void:
	_stop_pulse()
	if item.modulate.a < 0.01: return
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.set_trans(Tween.TRANS_SINE)
	_pulse_tween.tween_property(item, "modulate", Color.WHITE, 0.3)
	_pulse_tween.tween_property(item, "modulate", Color(0.5, 0.5, 0.5), 0.3)


func _stop_pulse() -> void:
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_pulse_tween = null


# ═══ 索引 ═══

func _max_idx() -> int:
	match _section:
		Section.STAGE: return _stages.size() - 1
		Section.PHASE: return _phases.size() - 1
		Section.DIFF:
			if _phase_index >= _phases.size(): return -1
			var info = _phases[_phase_index]
			return info["diffs"].keys().size() - 1
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
	if not _input_ready: return

	if event.is_action_pressed("ui_cancel"):
		sfx_back()
		if _section == Section.STAGE:
			go_back()
		else:
			_section -= 1
			_highlight()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("ui_left"):
		sfx_nav()
		_char_index = wrapi(_char_index - 1, 0, CHAR_NAMES.size())
		_refresh_char()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_right"):
		sfx_nav()
		_char_index = wrapi(_char_index + 1, 0, CHAR_NAMES.size())
		_refresh_char()
		get_viewport().set_input_as_handled()

	var mx := _max_idx()
	if mx < 0: return

	if event.is_action_pressed("ui_up"):
		sfx_nav()
		_set_idx(wrapi(_get_idx() - 1, 0, mx + 1))
		_highlight()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_down"):
		sfx_nav()
		_set_idx(wrapi(_get_idx() + 1, 0, mx + 1))
		_highlight()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		sfx_confirm()
		if _section == Section.DIFF:
			_start_practice()
		else:
			_flash_then(func(): _do_accept_transition())
		get_viewport().set_input_as_handled()


func _flash_then(on_done: Callable) -> void:
	var item := _get_highlighted_item()
	if item:
		var tw := item.create_tween()
		tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.set_loops(2)
		tw.tween_property(item, "modulate", Color(0.25, 0.25, 0.25), 0.06)
		tw.tween_property(item, "modulate", Color.WHITE, 0.06)

	var delay := create_tween()
	delay.tween_interval(0.24)
	delay.tween_callback(on_done)


func _do_accept_transition() -> void:
	if _section == Section.STAGE:
		_section = Section.PHASE
	elif _section == Section.PHASE:
		_section = Section.DIFF
		_diff_index = 0
		_build_diff_list()
	_highlight()


func _get_highlighted_item() -> Control:
	match _section:
		Section.STAGE:
			var c := _stage_box.get_children()
			return c[_stage_index] if _stage_index < c.size() else null
		Section.PHASE:
			var c := _phase_box.get_children()
			return c[_phase_index] if _phase_index < c.size() else null
		Section.DIFF:
			var c := _diff_box.get_children()
			return c[_diff_index] if _diff_index < c.size() else null
	return null


# ═══ 开始练习 ═══

func _start_practice() -> void:
	if _phase_index >= _phases.size(): return
	var info = _phases[_phase_index]
	if info["diffs"].is_empty(): return
	var diffs: Array = info["diffs"].keys()
	diffs.sort()
	var diff: int = diffs[_diff_index]
	var card: CardDef = info["card"]

	GameState.selected_difficulty = diff
	GameState.selected_character = _char_index

	print("练习: ", card.name, " 难度: ", diff_name(diff))
	GameState.start_practice(card, _char_index, diff)
	AudioManager.stop_bgm()
	_on_leave()
	GameManager.change_scene("res://scenes/game_scene.tscn")
