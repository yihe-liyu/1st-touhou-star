# DialogueBox.gd
extends CanvasLayer

## 对话框 — 左右立绘 + 打字机文字 + 跳过
##
## 用法:
##   var box := DIALOGUE_BOX.instantiate()
##   add_child(box)
##   box.play(data)  # 阻塞到结束, signal finished

signal finished()

@export var text_speed: float = 0.04  # 每字间隔秒
@export var show_arrow: bool = true

@onready var _root: Control = $Control
@onready var _left_column: VBoxContainer = $Control/LeftColumn
@onready var _right_column: VBoxContainer = $Control/RightColumn
@onready var _text_label: Label = $Control/TextBox/TextLabel
@onready var _arrow: Label = $Control/Arrow

var _data: DialogueData
var _line_index: int = 0
var _input_ready: bool = false
var _skipping: bool = false
var _typing_tween: Tween

func _ready() -> void:
	visible = false
	_arrow.visible = false
	_root.modulate.a = 0.0

func play(data: DialogueData) -> void:
	_data = data
	_line_index = 0
	visible = true
	
	# 淡入
	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", 1.0, 0.3)
	tw.tween_callback(_show_line)

func _input(event: InputEvent) -> void:
	if not _input_ready: return
	
	if event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		if _line_index >= _data.lines.size() - 1:
			_close()
		else:
			_line_index += 1
			_show_line()
	elif event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_skip_all()

func _show_line() -> void:
	var line := _data.lines[_line_index]
	
	# 清 + 重建立绘
	_clear_column(_left_column)
	_clear_column(_right_column)
	
	for ch in line.left_chars:
		_add_portrait(_left_column, ch, line.speakers, line.left_chars.size(), 0)
	for ch in line.right_chars:
		_add_portrait(_right_column, ch, line.speakers, line.left_chars.size(), line.left_chars.size())
	
	# 打字机
	_typing_tween = create_tween()
	_text_label.text = ""
	_input_ready = false
	_arrow.visible = false
	
	var full_text := line.text
	var total := float(full_text.length()) * text_speed
	
	_typing_tween.tween_method(_update_text.bind(full_text), 0.0, 1.0, total)
	_typing_tween.tween_callback(func():
		_input_ready = true
		_arrow.visible = true
	)

func _update_text(progress: float, full_text: String) -> void:
	var char_count := int(lerpf(0.0, float(full_text.length()), progress))
	_text_label.text = full_text.substr(0, char_count)

func _add_portrait(column: VBoxContainer, ch: DialogueCharacter, speakers: Array, _left_count: int, base_idx: int) -> void:
	var vbox := VBoxContainer.new()
	
	if ch.portrait:
		var tex := TextureRect.new()
		tex.texture = ch.portrait
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.custom_minimum_size = Vector2(120, 120)
		vbox.add_child(tex)
	
	if ch.char_name != "":
		var name_lbl := Label.new()
		name_lbl.text = ch.char_name
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 16)
		vbox.add_child(name_lbl)
	
	column.add_child(vbox)
	
	# 高亮说话者
	var global_idx := base_idx
	for i in range(column.get_child_count() - 1):
		global_idx = base_idx + i
	var is_speaker := speakers.has(global_idx)
	vbox.modulate = Color.WHITE if is_speaker else Color(0.35, 0.35, 0.35)

func _skip_all() -> void:
	_skipping = true
	if _typing_tween and _typing_tween.is_valid():
		_typing_tween.kill()
	_text_label.text = _data.lines[_line_index].text
	_close()

func _close() -> void:
	_input_ready = false
	_arrow.visible = false
	if _speaker_pulse and _speaker_pulse.is_valid():
		_speaker_pulse.kill()
	
	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", 0.0, 0.2)
	tw.tween_callback(func():
		finished.emit()
		queue_free()
	)

func _clear_column(column: VBoxContainer) -> void:
	for child in column.get_children():
		child.queue_free()

func _lerpf(a: float, b: float, t: float) -> float:
	return a + (b - a) * t
