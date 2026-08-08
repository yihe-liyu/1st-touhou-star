# SpellCardRecordMenu.gd — 符卡记录页面
# 只显示符卡（uid!=0）；每行：符卡名 + 普通模式收取 n/m（captures/attempts）
# 顶部：角色（←→ 切换）× 难度（↑↓ 切换）；仅展示；多页时 Z 翻页
extends BasePage

const CHAR_NAMES = SpellRecord.CHAR_NAMES
const DIFF_NAMES = SpellRecord.DIFF_NAMES
const PER_PAGE := 6  # 每页符卡数（超了 Z 翻页）

var _char_index: int = 0
var _diff_index: int = 0
var _cards: Array[Dictionary] = []  # 去重后的符卡 {stage, phase_index, boss_index, name}
var _page: int = 0


func _ready() -> void:
	_char_index = clampi(GameState.selected_character, 0, CHAR_NAMES.size() - 1)
	_diff_index = clampi(GameState.selected_difficulty, 0, DIFF_NAMES.size() - 1)
	_collect_cards()
	_update_header()
	_render()


# ═══ 数据 ═══

## 从记录扫全部符卡（uid!=0 且 SPELL），按 (stage, phase_index, boss_index) 去重
func _collect_cards() -> void:
	var seen := {}
	_cards.clear()
	var book: SpellRecordBook = GameState.spell_book
	for r in book.records:
		if r.uid == 0 or r.phase_type != SpellRecord.PhaseType.SPELL:
			continue
		var key := "%d_%d_%d" % [r.stage, r.phase_index, r.boss_index]
		if seen.has(key):
			continue
		seen[key] = true
		_cards.append({
			"stage": r.stage, "phase_index": r.phase_index, "boss_index": r.boss_index,
			"name": r.name,
		})
	_cards.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["stage"] < b["stage"] or (a["stage"] == b["stage"] and a["phase_index"] < b["phase_index"]))


## 取当前角色+难度下某张卡的记录
func _record_of(card: Dictionary) -> SpellRecord:
	return GameState.spell_book.get_record(card["stage"], card["phase_index"], card["boss_index"],
		_char_index, _diff_index)


func _total_pages() -> int:
	return maxi(1, int(ceil(_cards.size() / float(PER_PAGE))))


# ═══ 渲染 ═══

func _update_header() -> void:
	$Header/CharLabel.text = "← %s →" % CHAR_NAMES[_char_index]
	$Header/DiffLabel.text = DIFF_NAMES[_diff_index]


func _render() -> void:
	var box: VBoxContainer = $"LeftPanel/ListBox"
	for c in box.get_children():
		c.queue_free()

	if _cards.is_empty():
		var empty := Label.new()
		empty.text = "暂无符卡记录"
		empty.add_theme_font_size_override("font_size", 26)
		empty.modulate.a = 0.6
		box.add_child(empty)
	else:
		var start := _page * PER_PAGE
		for i in range(start, mini(start + PER_PAGE, _cards.size())):
			box.add_child(_make_row(_cards[i]))

	# 页数提示（多页时才显示）
	var pages := _total_pages()
	$PageLabel.visible = pages > 1
	if pages > 1:
		$PageLabel.text = "Z 翻页  %d/%d" % [min(_page + 1, pages), pages]


func _make_row(card: Dictionary) -> HBoxContainer:
	var rec := _record_of(card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var name_l := Label.new()
	name_l.text = card["name"]
	name_l.add_theme_font_size_override("font_size", 26)
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var stat_l := Label.new()
	if rec:
		stat_l.text = "%d/%d" % [rec.captures, rec.attempts]
		stat_l.add_theme_color_override("font_color",
			Color(1.0, 0.9, 0.5) if rec.captures > 0 else Color(0.72, 0.72, 0.78))
	else:
		stat_l.text = "--"
		stat_l.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
	stat_l.add_theme_font_size_override("font_size", 26)
	stat_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(name_l)
	row.add_child(stat_l)
	return row


# ═══ 输入 ═══

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		sfx_back()
		go_back()
		return
	if event.is_action_pressed("ui_left"):
		get_viewport().set_input_as_handled()
		_char_index = wrapi(_char_index - 1, 0, CHAR_NAMES.size())
		_page = 0
		_update_header()
		_render()
		sfx_nav()
	elif event.is_action_pressed("ui_right"):
		get_viewport().set_input_as_handled()
		_char_index = wrapi(_char_index + 1, 0, CHAR_NAMES.size())
		_page = 0
		_update_header()
		_render()
		sfx_nav()
	elif event.is_action_pressed("ui_up"):
		get_viewport().set_input_as_handled()
		_diff_index = wrapi(_diff_index - 1, 0, DIFF_NAMES.size())
		_page = 0
		_update_header()
		_render()
		sfx_nav()
	elif event.is_action_pressed("ui_down"):
		get_viewport().set_input_as_handled()
		_diff_index = wrapi(_diff_index + 1, 0, DIFF_NAMES.size())
		_page = 0
		_update_header()
		_render()
		sfx_nav()
	elif event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		if _total_pages() > 1:
			_page = (_page + 1) % _total_pages()
			_render()
			sfx_nav()


# ═══ 生命周期 ═══

func _on_enter() -> void:
	var ov: ColorRect = $"Overlay"
	ov.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(ov, "modulate:a", 1.0, 0.4)


func _on_leave() -> void:
	var tw := create_tween()
	tw.tween_property($"Overlay", "modulate:a", 0.0, 0.4)
	tw.tween_callback(queue_free)
