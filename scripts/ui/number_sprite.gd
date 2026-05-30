extends Node2D
class_name NumberSprite
## 用贴图显示数字 —— 横向排列 0-9 的 sprite sheet
## 每帧更新，自动创建/回收数字精灵

@export var digit_texture: Texture2D
@export var char_count: int = 14       # 贴图里字符总数
@export var dot_index: int = 11        # 小数点在第几位
@export var slash_index: int = 12     # 斜杠在第几位（-1=不显示）
@export var pct_index: int = 14      # % 在第几位
@export var minus_index: int = 13    # - 在第几位
@export var left_align: bool = false   # true=左对齐不留前导零
@export var digit_count: int = 8       # 最大显示位数
@export var digit_spacing: float = 24.0  # 字符间距
@export var value: int = 0:
	set(v):
		value = v
		_text = ""

var _digits: Array[Sprite2D] = []
var _text: String = ""  # 如果设置了 text，优先用 text


func _ready() -> void:
	_setup_digits()


func _setup_digits() -> void:
	var w: float = digit_texture.get_width() / float(char_count) if digit_texture and char_count > 0 else 0.0
	var h: float = digit_texture.get_height() if digit_texture else 0.0
	for i in range(digit_count):
		var s: Sprite2D = Sprite2D.new()
		s.texture = digit_texture
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.region_enabled = true
		s.region_rect = Rect2(0, 0, w, h)
		s.position.x = i * digit_spacing
		s.visible = false
		add_child(s)
		_digits.append(s)


func _process(_delta: float) -> void:
	var text := _text
	if text == "":
		if left_align:
			text = str(value)
		else:
			text = "%0*d" % [digit_count, value]
	
	# 右对齐偏移量
	var offset := 0
	if not left_align:
		offset = digit_count - text.length()
	
	for i in range(digit_count):
		if offset > 0 and i < offset:
			_digits[i].visible = false
			continue
		
		var ti := i - offset
		if ti < 0 or ti >= text.length():
			_digits[i].visible = false
			continue
		
		var ch := text[ti]
		var idx := -1
		if ch >= "0" and ch <= "9":
			idx = ch.to_int()
		elif ch == ".":
			idx = dot_index
		elif ch == "/":
			idx = slash_index
		elif ch == "%":
			idx = pct_index
		elif ch == "-":
			idx = minus_index
		
		if idx >= 0:
			var tex_w: float = float(digit_texture.get_width())
			var exact_x: float = idx * tex_w / float(char_count)
			var exact_w: float = tex_w / float(char_count)
			_digits[i].region_rect = Rect2(exact_x, 0, exact_w, digit_texture.get_height())
			_digits[i].visible = true
		else:
			_digits[i].visible = false


func show_text(t: String) -> void:
	_text = t  # _process 每帧读，无需 queue_redraw
