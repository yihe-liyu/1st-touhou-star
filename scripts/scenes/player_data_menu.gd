# PlayerDataMenu.gd — 玩家数据菜单（三个竖排选项：中文主名 + 英文小标题）
extends BasePage

const OPTIONS: Array[Dictionary] = [
	{"zh": "分数排行", "en": "Score Ranking"},
	{"zh": "符卡记录", "en": "SpellCard Record"},
	{"zh": "奖杯", "en": "Trophy"},
]

const HOVER_TINT := Color(1.0, 0.9, 0.5, 1.0)   # 悬停/选中金色
const SUB_COLOR := Color(0.72, 0.72, 0.78, 1.0) # 英文小标题暗色

var _items: Array[VBoxContainer] = []
var _hover_idx: int = 0


func _ready() -> void:
	_build_options()
	_apply_hover()


func _build_options() -> void:
	var box: VBoxContainer = $"LeftPanel/ListContainer"
	box.add_theme_constant_override("separation", 30)
	box.alignment = BoxContainer.ALIGNMENT_CENTER  # 面板内上下居中
	for o in OPTIONS:
		var item := _make_item(o["zh"], o["en"])
		box.add_child(item)
		_items.append(item)


func _make_item(zh: String, en: String) -> VBoxContainer:
	var item := VBoxContainer.new()
	item.mouse_filter = Control.MOUSE_FILTER_STOP
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
	item.gui_input.connect(_on_item_input.bind(item))
	return item


func _on_item_input(event: InputEvent, item: VBoxContainer) -> void:
	if event is InputEventMouseMotion:
		var idx := _items.find(item)
		if idx >= 0 and idx != _hover_idx:
			_hover_idx = idx
			_apply_hover()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var idx := _items.find(item)
		if idx >= 0:
			_select(idx)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		sfx_back()
		go_back()
		return
	if event.is_action_pressed("ui_down"):
		get_viewport().set_input_as_handled()
		_hover_idx = (_hover_idx + 1) % _items.size()
		_apply_hover()
		sfx_nav()
	elif event.is_action_pressed("ui_up"):
		get_viewport().set_input_as_handled()
		_hover_idx = (_hover_idx - 1 + _items.size()) % _items.size()
		_apply_hover()
		sfx_nav()
	elif event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_select(_hover_idx)


func _apply_hover() -> void:
	for i in _items.size():
		_items[i].modulate = HOVER_TINT if i == _hover_idx else Color.WHITE


func _select(idx: int) -> void:
	# 占位：功能后续接入（分数排行/符卡记录/奖杯页面）
	print("[PlayerDataMenu] 选择：%s" % OPTIONS[idx]["zh"])


func _on_enter() -> void:
	var ov: ColorRect = $"Overlay"
	ov.modulate.a = 0.0
	var tex: TextureRect = $"TitleTexture"
	tex.modulate.a = 0.0
	for item in _items:
		item.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(ov, "modulate:a", 1.0, 0.5)
	tw.tween_property(tex, "modulate:a", 1.0, 0.5)
	for i in _items.size():
		tw.tween_property(_items[i], "modulate:a", 1.0, 0.35).set_delay(0.15 + i * 0.08)


func _on_leave() -> void:
	var tw := create_tween().set_parallel(true)
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property($"Overlay", "modulate:a", 0.0, 0.5)
	tw.tween_property($"TitleTexture", "modulate:a", 0.0, 0.5)
	tw.tween_callback(queue_free)
