# PlayerDataMenu.gd — 玩家数据菜单（三个竖排选项：中文主名 + 英文小标题）
# 继承 NavPage：未选中暗(0.4)、选中白+脉冲闪烁、交错滑入（与主菜单一致画风）
extends NavPage

const OPTIONS: Array[Dictionary] = [
	{"zh": "分数排行", "en": "Score Ranking"},
	{"zh": "符卡记录", "en": "SpellCard Record"},
	{"zh": "奖杯", "en": "Trophy"},
]

const SUB_COLOR := Color(0.72, 0.72, 0.78, 1.0)  # 英文小标题暗色（选中时整体变白，副题仍偏暗层次）


func _ready() -> void:
	_build_options()


func _build_options() -> void:
	var box: VBoxContainer = $"LeftPanel/ListContainer"
	box.add_theme_constant_override("separation", 30)
	box.alignment = BoxContainer.ALIGNMENT_CENTER  # 面板内上下居中
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
			GameManager.push_page("res://scenes/ui/spellcard_record_menu.tscn")
		_:
			# 占位：分数排行/奖杯 后续接入
			print("[PlayerDataMenu] 选择：%s" % OPTIONS[index]["zh"])


func _on_cancel() -> void:
	go_back()
