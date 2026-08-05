class_name WorkbenchTheme
extends RefCounted
## 工作台主题 —— 东方风深色面板（Theme + StyleBox 统一定制）
##
## 设计：
##   · 深蓝黑底 + 卡片分层（PanelContainer 圆角卡片）
##   · 金色强调（东方风）+ 蓝灰边框
##   · 中文字体：SystemFont 引用 Noto Sans CJK（开发机有系统字体；
##     发布时需打包字体到 export 或用 SystemFont 运行时查找）
##
## 用法：workbench 根 Control.theme = WorkbenchTheme.build()

const BG := Color(0.045, 0.06, 0.09, 0.97)
const CARD := Color(0.085, 0.105, 0.145, 0.95)
const CARD_HOVER := Color(0.13, 0.16, 0.22, 0.95)
const CARD_PRESSED := Color(0.05, 0.06, 0.09, 0.95)
const INPUT_BG := Color(0.05, 0.065, 0.095, 1.0)
const BORDER := Color(0.17, 0.21, 0.29, 1.0)
const BORDER_HOVER := Color(0.90, 0.70, 0.25, 0.65)
const TEXT := Color(0.91, 0.94, 0.98, 1.0)
const TEXT_DIM := Color(0.70, 0.75, 0.83, 1.0)
const ACCENT := Color(0.92, 0.73, 0.32, 1.0)
const SELECT := Color(0.35, 0.55, 0.95, 0.35)


## 构建主题（每次调用新实例；workbench 只调一次）
static func build() -> Theme:
	var t := Theme.new()
	# ── 中文字体（SystemFont 按系统名 fallback；emoji 兜底显示日志装饰）──
	# 清晰度三件套：hinting LIGHT（CJK 小字号不发虚）、weight 500（比 400 粗一点更实）、
	# 字号 15（原 14 在低分屏上偏糊）——面板所有字都走 default_font
	var font := SystemFont.new()
	font.font_names = PackedStringArray([
		"Noto Sans CJK JP", "Noto Sans CJK SC", "Noto Sans CJK TC",
		"WenQuanYi Micro Hei", "Noto Sans", "Noto Color Emoji",
	])
	font.font_weight = 500
	font.hinting = TextServer.HINTING_LIGHT
	font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
	t.default_font = font
	t.default_font_size = 15

	# ── 卡片（PanelContainer：区块/弹窗面板）──
	t.set_stylebox("panel", "PanelContainer", _card())

	# ── Button ──
	_style_button(t, "Button")
	_style_button(t, "OptionButton")

	# ── 输入框（LineEdit / SpinBox 共享）──
	var input := StyleBoxFlat.new()
	input.bg_color = INPUT_BG
	input.set_border_width_all(1)
	input.border_color = BORDER
	input.set_corner_radius_all(4)
	input.set_content_margin_all(5)
	t.set_stylebox("normal", "LineEdit", input)
	var input_focus := input.duplicate() as StyleBoxFlat
	input_focus.border_color = ACCENT
	t.set_stylebox("focus", "LineEdit", input_focus)
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_color("caret_color", "LineEdit", ACCENT)

	# ── CheckButton / CheckBox ──
	t.set_color("font_color", "CheckButton", TEXT)
	t.set_color("font_hover_color", "CheckButton", Color.WHITE)
	t.set_color("font_pressed_color", "CheckButton", ACCENT)
	t.set_color("font_color", "CheckBox", TEXT)

	# ── ItemList（书签/列表）──
	var il := StyleBoxFlat.new()
	il.bg_color = CARD
	il.set_border_width_all(1)
	il.border_color = BORDER
	il.set_corner_radius_all(6)
	il.set_content_margin_all(4)
	t.set_stylebox("panel", "ItemList", il)
	t.set_color("font_color", "ItemList", TEXT)
	t.set_color("font_selected_color", "ItemList", Color.WHITE)
	t.set_color("selected", "ItemList", SELECT)
	t.set_color("cursor", "ItemList", ACCENT)

	# ── RichTextLabel（日志）──
	t.set_color("default_color", "RichTextLabel", TEXT)
	t.set_color("scroll_color", "RichTextLabel", Color(1, 1, 1, 0.1))

	# ── Label ──
	t.set_color("font_color", "Label", TEXT)

	# ── 滚动条（细窄半透明）──
	var scroll_bg := StyleBoxFlat.new()
	scroll_bg.bg_color = Color(BG, 0.55)
	t.set_stylebox("panel", "ScrollContainer", scroll_bg)
	var grabber := StyleBoxFlat.new()
	grabber.bg_color = Color(1, 1, 1, 0.14)
	grabber.set_corner_radius_all(4)
	t.set_stylebox("grabber", "VScrollBar", grabber)
	t.set_stylebox("grabber", "HScrollBar", grabber)
	var grabber_hover := grabber.duplicate() as StyleBoxFlat
	grabber_hover.bg_color = Color(0.92, 0.73, 0.32, 0.35)
	t.set_stylebox("grabber_highlight", "VScrollBar", grabber_hover)
	t.set_stylebox("grabber_highlight", "HScrollBar", grabber_hover)
	t.set_stylebox("track", "VScrollBar", StyleBoxEmpty.new())
	t.set_stylebox("track", "HScrollBar", StyleBoxEmpty.new())
	t.set_constant("width", "VScrollBar", 6)
	t.set_constant("width", "HScrollBar", 6)

	# ── 弹窗（DialogHost 的 PanelContainer）──
	t.set_stylebox("panel", "PopupPanel", _card())

	# ── SpinBox 微调（组合 LineEdit + 箭头按钮）──
	t.set_constant("separation", "SpinBox", 0)
	return t


## 卡片样式（圆角 + 边框 + 内容边距）
static func _card() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = CARD
	sb.set_border_width_all(1)
	sb.border_color = BORDER
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(10)
	return sb


## 按钮三态样式
static func _style_button(t: Theme, type: String) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = CARD
	normal.set_border_width_all(1)
	normal.border_color = BORDER
	normal.set_corner_radius_all(6)
	normal.set_content_margin_all(6)
	t.set_stylebox("normal", type, normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = CARD_HOVER
	hover.border_color = BORDER_HOVER
	t.set_stylebox("hover", type, hover)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = CARD_PRESSED
	pressed.border_color = ACCENT
	t.set_stylebox("pressed", type, pressed)
	t.set_stylebox("focus", type, StyleBoxEmpty.new())
	t.set_color("font_color", type, TEXT)
	t.set_color("font_hover_color", type, Color.WHITE)
	t.set_color("font_pressed_color", type, ACCENT)
