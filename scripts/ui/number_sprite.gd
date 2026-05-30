extends Node2D
class_name NumberSprite
## 用贴图显示数字 —— 横向排列 0-9 的 sprite sheet
## 每帧更新，自动创建/回收数字精灵

@export var digit_texture: Texture2D  # 0-9 横向排列
@export var digit_count: int = 8       # 最大位数
@export var digit_spacing: float = 16.0
@export var value: int = 0:
	set(v):
		value = v
		queue_redraw()

var _digits: Array[Sprite2D] = []
var _digit_width: float = 0.0


func _ready() -> void:
	if digit_texture:
		_digit_width = digit_texture.get_width() / 10.0
	_setup_digits()


func _setup_digits() -> void:
	for i in range(digit_count):
		var s := Sprite2D.new()
		s.texture = digit_texture
		s.region_enabled = true
		s.region_rect = Rect2(0, 0, _digit_width, digit_texture.get_height())
		s.position.x = i * digit_spacing
		s.visible = false
		add_child(s)
		_digits.append(s)


func _process(_delta: float) -> void:
	var text := "%0*d" % [digit_count, value]
	for i in range(digit_count):
		if i >= text.length():
			_digits[i].visible = false
			continue
		var ch := text[i]
		if ch >= "0" and ch <= "9":
			var idx := ch.to_int()
			_digits[i].region_rect = Rect2(idx * _digit_width, 0, _digit_width, digit_texture.get_height())
			_digits[i].visible = true
		else:
			_digits[i].visible = false
