# DialogueBox.gd
extends CanvasLayer
## 气泡对话 v2 — 立绘旁出气泡

signal finished()

@export var text_speed: float = 0.04

@onready var _root: Control = $Control
@onready var _left_col: VBoxContainer = $Control/LeftColumn
@onready var _right_col: VBoxContainer = $Control/RightColumn
@onready var _arrow: Label = $Control/Arrow

var _data: Resource  # DialogueData
var _line_idx: int = 0
var _input_ready: bool = false
var _typing_tween: Tween

# profile -> {node: VBoxContainer, side: int}
var _portrait_map: Dictionary = {}

func _ready() -> void:
	visible = false
	_arrow.visible = false
	_root.modulate.a = 0.0
	_left_col.position = Vector2(40, 80)
	_right_col.position = Vector2(700, 80)

func play(data: Resource) -> void:  # data: DialogueData
	_data = data
	_line_idx = 0
	visible = true
	
	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", 1.0, 0.3)
	tw.tween_callback(_show_line)

func _input(event: InputEvent) -> void:
	if not _input_ready: return
	if event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		if _line_idx >= _data.lines.size() - 1:
			_close()
		else:
			_line_idx += 1
			_show_line()
	elif event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()

func _show_line() -> void:
	_clear_bubbles()
	var line: Resource = _data.lines[_line_idx]  # DialogueLine
	
	# 决定谁在场
	var active: Dictionary = {}
	for pos in line.positions:
		active[pos.character] = pos.side
	
	# 去掉不在场的 → 淡出
	for profile in _portrait_map.keys():
		if not active.has(profile):
			var node: Control = _portrait_map[profile].node
			_fade_out(node)
	
	# 添加/恢复在场的
	for pos in line.positions:
		var profile: Resource = pos.character  # CharacterProfile
		if _portrait_map.has(profile):
			var node: Control = _portrait_map[profile].node
			node.modulate = Color.WHITE
			_update_portrait_texture(profile, node)
		else:
			_add_portrait(profile, pos.side)
	
	# 说话者高亮, 其余暗
	var speakers: Dictionary = {}
	for b in line.bubbles:
		speakers[b.speaker] = true
	for profile in _portrait_map.keys():
		var node: Control = _portrait_map[profile].node
		node.modulate = Color.WHITE if speakers.has(profile) else Color(0.4, 0.4, 0.4)
	
	# 创建气泡
	for b in line.bubbles:
		_create_bubble(b.speaker, b.text, b.emotion)
	
	# 打字机
	_input_ready = false
	_arrow.visible = false
	if line.bubbles.size() > 0:
		_animate_text(line.bubbles)

func _animate_text(bubbles: Array) -> void:
	# 取最长文本
	var full_text := ""
	for b in bubbles:
		if b.text.length() > full_text.length():
			full_text = b.text
	
	_typing_tween = create_tween()
	var total := float(full_text.length()) * text_speed
	
	_typing_tween.tween_method(
		_update_text_progress.bind(bubbles, full_text.length()),
		0.0, 1.0, total
	)
	_typing_tween.tween_callback(func():
		_input_ready = true
		_arrow.visible = true
	)

func _update_text_progress(progress: float, bubbles: Array, max_len: int) -> void:
	var global_char := int(lerpf(0.0, float(max_len), progress))
	for b in bubbles:
		var node: Dictionary = _portrait_map.get(b.speaker, {})
		if node.is_empty(): continue
		var lbl: Label = node.node.get_meta("_bubble_label", null)
		if not lbl: continue
		var local_char := clampi(global_char, 0, b.text.length())
		lbl.text = b.text.substr(0, local_char)

# ═══ 立绘 ═══

func _add_portrait(profile: Resource, side: int) -> void:
	var vbox := VBoxContainer.new()
	
	var tex := TextureRect.new()
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	vbox.add_child(tex)
	_update_portrait_texture(profile, vbox)
	
	var lbl := Label.new()
	lbl.text = profile.char_name
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 16)
	vbox.add_child(lbl)
	
	var col := _left_col if side == 0 else _right_col
	col.add_child(vbox)
	vbox.modulate = Color(0.4, 0.4, 0.4)
	_portrait_map[profile] = {node = vbox, side = side}

func _update_portrait_texture(profile: Resource, vbox: VBoxContainer) -> void:
	if vbox.get_child_count() > 0 and vbox.get_child(0) is TextureRect:
		var tex: TextureRect = vbox.get_child(0)
		if profile.portraits.has("通常"):
			tex.texture = profile.portraits["通常"]
			tex.custom_minimum_size = tex.texture.get_size()

# ═══ 气泡 ═══

func _create_bubble(speaker: Resource, text: String, _emotion: String) -> void:
	var info: Dictionary = _portrait_map.get(speaker, {})
	if info.is_empty(): return
	var node: Control = info.node
	var side: int = info.side
	
	_clear_child_bubbles(node)
	
	var bubble := Label.new()
	bubble.add_theme_color_override("font_color", Color.WHITE)
	bubble.add_theme_font_size_override("font_size", 20)
	bubble.custom_minimum_size = Vector2(280, 0)
	node.add_child(bubble)
	
	var node_size := node.size
	if side == 0:
		bubble.position = Vector2(node_size.x + 12, 0)
	else:
		bubble.position = Vector2(-292, 0)
	
	node.set_meta("_bubble_label", bubble)

func _clear_child_bubbles(parent: Control) -> void:
	if parent.has_meta("_bubble_label"):
		var lbl: Label = parent.get_meta("_bubble_label")
		if is_instance_valid(lbl):
			lbl.queue_free()
		parent.remove_meta("_bubble_label")

func _clear_bubbles() -> void:
	for info in _portrait_map.values():
		_clear_child_bubbles(info.node)

func _fade_out(node: Control) -> void:
	var tw := create_tween()
	tw.tween_property(node, "modulate:a", 0.0, 0.3)

# ═══ 关闭 ═══

func _close() -> void:
	_input_ready = false
	_arrow.visible = false
	if _typing_tween and _typing_tween.is_valid():
		_typing_tween.kill()
	
	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", 0.0, 0.2)
	tw.tween_callback(func():
		finished.emit()
		queue_free()
	)
