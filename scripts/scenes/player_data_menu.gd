# PlayerDataMenu.gd — 玩家数据菜单（场景内视图切换）
# 选项视图：三个竖排选项（中文主名+英文小标题，NavPage 导航：未选中暗/选中白+闪烁）
# 符卡记录视图：只显示符卡(uid!=0)，每行符卡名+普通模式收取 n/m；顶部角色(←→)×难度(↑↓)；多页 Z 翻页
extends NavPage

enum View { OPTIONS, RECORD }

const OPTIONS: Array[Dictionary] = [
	{"zh": "分数排行", "en": "Score Ranking"},
	{"zh": "符卡记录", "en": "SpellCard Record"},
	{"zh": "奖杯", "en": "Trophy"},
]

const CHAR_NAMES = SpellRecord.CHAR_NAMES
const DIFF_NAMES = SpellRecord.DIFF_NAMES
const SUB_COLOR := Color(0.72, 0.72, 0.78, 1.0)  # 英文小标题暗色
const PER_PAGE := 6

var _view: int = View.OPTIONS
var _char_index: int = 0
var _diff_index: int = 0
var _cards: Array[Dictionary] = []
var _page: int = 0


# ═══ 选项视图构建 ═══

func _ready() -> void:
	_build_options()
	_char_index = clampi(GameState.selected_character, 0, CHAR_NAMES.size() - 1)
	_diff_index = clampi(GameState.selected_difficulty, 0, DIFF_NAMES.size() - 1)
	_collect_cards()


func _build_options() -> void:
	var box: VBoxContainer = $"LeftPanel/ListContainer"
	box.add_theme_constant_override("separation", 30)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	for o in OPTIONS:
		box.add_child(_make_item(o["zh"], o["en"]))


func _make_item(zh: String, en: String) -> VBoxContainer:
	var item := VBoxContainer.new()
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item.add_theme_constant_override("separation", 2)
	var main := Label.new()
	main.text = zh
	main.add_theme_font_size_override("font_size", 32)
	main.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var sub := Label.new()
	sub.text = en
	sub.add_theme_font_size_override("font_size", 15)
	sub.add_theme_color_override("font_color", SUB_COLOR)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	item.add_child(main)
	item.add_child(sub)
	return item


# ═══ 视图切换 ═══

func _show_record_view() -> void:
	_view = View.RECORD
	_nav_enabled = false  # 禁 NavPage 导航，改由本页处理角色/难度/Z/X
	_stop_pulse()
	$"LeftPanel".visible = false
	$RecordView.visible = true
	_update_header()
	_render()


func _hide_record_view() -> void:
	_view = View.OPTIONS
	$RecordView.visible = false
	$"LeftPanel".visible = true
	_nav_enabled = true
	# 冷却：同帧 _input 已处理 cancel，挡住 NavPage._process 的重复 cancel（否则直接退出页面）
	_last_accept_time = Time.get_ticks_msec() / 1000.0
	if _nav_index >= 0 and _nav_index < _nav_items.size():
		_start_pulse(_nav_items[_nav_index])


# ═══ 符卡记录数据 ═══

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


func _record_of(card: Dictionary) -> SpellRecord:
	return GameState.spell_book.get_record(card["stage"], card["phase_index"], card["boss_index"],
		_char_index, _diff_index)


func _total_pages() -> int:
	return maxi(1, int(ceil(_cards.size() / float(PER_PAGE))))


func _update_header() -> void:
	$RecordView/Header/CharLabel.text = "← %s →" % CHAR_NAMES[_char_index]
	$RecordView/Header/DiffLabel.text = DIFF_NAMES[_diff_index]


func _render() -> void:
	var box: VBoxContainer = $"RecordView/RecordPanel/ListBox"
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

	var pages := _total_pages()
	$RecordView/PageLabel.visible = pages > 1
	if pages > 1:
		$RecordView/PageLabel.text = "Z 翻页  %d/%d" % [min(_page + 1, pages), pages]


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
	if _view != View.RECORD:
		return  # 选项视图交给 NavPage._process 导航
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		sfx_back()
		_hide_record_view()
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
	# 遮罩/标题淡入（BasePage），再走 NavPage 的选项收集 + 交错入场
	var tex: TextureRect = $"TitleTexture"
	tex.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(tex, "modulate:a", 1.0, 0.5)
	_fade_overlay_in(0.5)
	super()


func _on_item_selected(index: int) -> void:
	match index:
		1:
			_show_record_view()
		_:
			# 占位：分数排行/奖杯 后续接入
			print("[PlayerDataMenu] 选择：%s" % OPTIONS[index]["zh"])


func _on_cancel() -> void:
	go_back()
