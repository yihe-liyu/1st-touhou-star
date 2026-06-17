extends CanvasLayer
## 气泡对话系统 — 立绘 + 飘浮气泡（带尾巴 + 防重叠）
##
## 操作:
##   Z / Enter     → 下一句 / 结束对话
##   X (短按)      → 跳过本句（若 skippable=true）
##   X (长按 0.6s) → 关闭整个对话
##
## 文本标记:
##   [shake=N]  — 气泡抖动 N 秒 (默认 0.3s)
##   BBCode 颜色 — [color=red]文字[/color] 等（Label 原生支持）

signal finished()

## 长按取消键多久关闭对话
@export var cancel_hold_threshold: float = 0.6
## 新句出现后的输入冷却（防止误触跳过）
@export var input_cooldown: float = 0.2

@onready var _root: Control = $Control

var _data: Array
var _line_idx: int = 0
var _input_ready: bool = false
var _portrait_map: Dictionary = {}
var _sticky_pos: Dictionary = {}  # char_name → 上次立绘位置
var _sticky_bubble: Dictionary = {}  # char_name → 上次气泡偏移
var _cancel_held: float = 0.0
var _auto_timer: float = 0.0
var _is_closing: bool = false

# ═══ 生命周期 ═══

func _ready() -> void:
	visible = false
	_root.modulate.a = 0.0

func play(lines: Array) -> void:
	process_mode = PROCESS_MODE_ALWAYS  # 暂停时也跑
	_data = lines
	_line_idx = 0
	_is_closing = false
	visible = true
	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", 1.0, 0.3)
	tw.tween_callback(_show_line)
	
	if not GameManager.game_state_changed.is_connected(_on_game_state):
		GameManager.game_state_changed.connect(_on_game_state)

func _process(delta: float) -> void:
	if _is_closing or not _data or not _input_ready:
		return

	# 长按取消 → 关闭对话
	if Input.is_action_pressed("ui_cancel"):
		_cancel_held += delta
		if _cancel_held >= cancel_hold_threshold:
			_close()
			return
	else:
		_cancel_held = 0.0

	# 自动播放
	var line: DialogueLine = _data[_line_idx]
	if line.auto_advance > 0.0:
		_auto_timer += delta
		if _auto_timer >= line.auto_advance:
			_advance()

func _input(event: InputEvent) -> void:
	if _is_closing or not _input_ready or not _data:
		return
	# 暂停时不处理输入
	if GameManager.current_state == GameManager.AppState.PAUSED:
		return

	if event.is_action_pressed("ui_cancel"):
		_cancel_held = 0.0

	if event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_advance()

	elif event.is_action_released("ui_cancel"):
		# 短按取消 = 跳过本句
		if _cancel_held < cancel_hold_threshold and _data[_line_idx].skippable:
			get_viewport().set_input_as_handled()
			_advance()

# ═══ 翻页 ═══

func _advance() -> void:
	if _line_idx >= _data.size() - 1:
		_close()
	else:
		_line_idx += 1
		_show_line()

# ═══ 显示一行 ═══

func _show_line() -> void:
	_clear_bubbles()
	_cancel_held = 0.0
	_auto_timer = 0.0

	var line: DialogueLine = _data[_line_idx]

	# ── 收集在场角色 ──
	var present: Dictionary = {}
	var pos_map: Dictionary = {}
	var bubble_map: Dictionary = {}
	var speakers: Dictionary = {}

	for b in line.bubbles:
		present[b.speaker.char_name] = b.speaker
		if b.move_portrait:
			pos_map[b.speaker.char_name] = b.portrait_pos
		if b.move_bubble:
			bubble_map[b.speaker.char_name] = b.bubble_offset
		if not b.text.is_empty():
			speakers[b.speaker.char_name] = true

	# ── 隐藏离场角色 ──
	for name_key in _portrait_map.keys():
		if not present.has(name_key):
			_portrait_map[name_key].node.visible = false

	# ── 显示/更新在场角色 ──
	for name_key in present:
		var profile: CharacterProfile = present[name_key]
		var info: Dictionary = _portrait_map.get(name_key, {})
		var target_pos: Vector2
		# 新角色用 portrait_pos；旧角色仅在 move_portrait=true 时移动
		if info.is_empty() or pos_map.has(name_key):
			target_pos = pos_map.get(name_key, Vector2(400, 200))
		else:
			target_pos = _sticky_pos.get(name_key, Vector2(400, 200))
		_sticky_pos[name_key] = target_pos

		if info.is_empty():
			_add_portrait(profile, target_pos, name_key)
			info = _portrait_map[name_key]
			info.node.modulate.a = 0.0
		else:
			info.node.visible = true
			info.profile = profile

		# 位置渐变
		var tw_pos := create_tween().set_parallel(true)
		tw_pos.tween_property(info.node, "position:x", target_pos.x, 0.35)\
			.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)
		tw_pos.tween_property(info.node, "position:y", target_pos.y, 0.35)\
			.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)

		# 亮度渐变
		var target_mod := Color.WHITE if speakers.has(name_key) else Color(0.35, 0.35, 0.35)
		var tw_mod := create_tween()
		tw_mod.tween_property(info.node, "modulate", target_mod, 0.25)

		info.node.z_index = 10 if speakers.has(name_key) else 0

	# ── 表情（所有在场角色，包括沉默者） ──
	for b in line.bubbles:
		var info: Dictionary = _portrait_map[b.speaker.char_name]
		_apply_emotion(info, b.emotion)

	# ── 创建气泡（仅说话者） ──
	for b in line.bubbles:
		if b.text.is_empty():
			continue
		var info: Dictionary = _portrait_map[b.speaker.char_name]

		var panel := BubblePanel.create(b.text)
		info.node.add_child(panel)
		# 气泡偏移：新角色或 move_bubble 时更新，否则粘滞
		var b_off: Vector2
		if bubble_map.has(b.speaker.char_name):
			b_off = bubble_map[b.speaker.char_name]
		else:
			b_off = _sticky_bubble.get(b.speaker.char_name, Vector2(12, 0))
		_sticky_bubble[b.speaker.char_name] = b_off
		panel.position = Vector2(info.node.size.x, 0) + b_off

		if panel._shake_dur > 0.0:
			_shake_bubble(panel)

		info.node.set_meta("_bubble_panel", panel)

	# ── 触发事件 ──
	if not line.event.is_empty():
		GameEvents.dialogue_event.emit(line.event)

	# ── 输入冷却 ──
	if input_cooldown > 0.0:
		_input_ready = false
		await get_tree().create_timer(input_cooldown).timeout
		if not is_inside_tree() or _is_closing:
			return

	_input_ready = true

# ═══ 表情切换 ═══

func _apply_emotion(info: Dictionary, emotion: String) -> void:
	var profile: CharacterProfile = info.get("profile")
	if not profile:
		return
	var ctrl: Control = info.node
	if ctrl.get_child_count() > 0 and ctrl.get_child(0) is TextureRect:
		var tex: TextureRect = ctrl.get_child(0)
		var key := emotion if not emotion.is_empty() else "通常"
		if profile.portraits.has(key):
			tex.texture = profile.portraits[key]

# ═══ 立绘节点 ═══

func _add_portrait(profile: CharacterProfile, pos: Vector2, name_key: String) -> void:
	var ctrl := Control.new()
	ctrl.position = pos

	var tex := TextureRect.new()
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ctrl.add_child(tex)

	if profile.portraits.has("通常"):
		tex.texture = profile.portraits["通常"]
		tex.custom_minimum_size = tex.texture.get_size()
		ctrl.custom_minimum_size = tex.texture.get_size()
		ctrl.size = tex.texture.get_size()

	_root.add_child(ctrl)
	_portrait_map[name_key] = {node = ctrl, profile = profile}

# ═══ 抖动 ═══

func _shake_bubble(panel: BubblePanel) -> void:
	var orig := panel.position
	var dur := panel._shake_dur
	var tw := create_tween()
	tw.set_loops()
	var shakes := ceili(dur / 0.05)
	for _i in shakes:
		var off := Vector2(randf_range(-4, 4), randf_range(-2, 2))
		tw.tween_property(panel, "position", orig + off, 0.025)
		tw.tween_property(panel, "position", orig, 0.025)
	await get_tree().create_timer(dur).timeout
	if is_instance_valid(panel):
		tw.kill()
		panel.position = orig

# ═══ 清理 ═══

func _clear_child_bubbles(parent: Control) -> void:
	if parent.has_meta("_bubble_panel"):
		var p: BubblePanel = parent.get_meta("_bubble_panel")
		if is_instance_valid(p):
			p.queue_free()
		parent.remove_meta("_bubble_panel")

func _clear_bubbles() -> void:
	for info in _portrait_map.values():
		_clear_child_bubbles(info.node)

func _close() -> void:
	_is_closing = true
	_input_ready = false
	_cancel_held = 0.0
	process_mode = PROCESS_MODE_INHERIT  # 恢复默认
	
	if GameManager.game_state_changed.is_connected(_on_game_state):
		GameManager.game_state_changed.disconnect(_on_game_state)
	
	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", 0.0, 0.2)
	tw.tween_callback(func():
		finished.emit()
		queue_free()
	)

func _on_game_state(_old: int, new: int) -> void:
	if new == GameManager.AppState.PAUSED:
		var tw := create_tween()
		tw.tween_property(_root, "modulate:a", 0.0, 0.15)
	elif new == GameManager.AppState.PLAYING:
		var tw := create_tween()
		tw.tween_property(_root, "modulate:a", 1.0, 0.15)


# ═══════════════════════════════════════
#  内部类：气泡面板
# ═══════════════════════════════════════

class BubblePanel extends PanelContainer:
	var _label: Label
	var _shake_dur: float = 0.0

	const PAD_H := 16.0
	const PAD_V := 10.0
	const MIN_W := 440.0

	static func create(text: String) -> BubblePanel:
		var panel := BubblePanel.new()
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

		# 样式（PanelContainer 用 "panel" 主题项）
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(1, 1, 1, 0.92)
		sb.set_corner_radius_all(10)
		sb.border_width_left   = 2
		sb.border_width_right  = 2
		sb.border_width_top    = 2
		sb.border_width_bottom = 2
		sb.border_color = Color(0.5, 0.5, 0.55, 0.7)
		sb.content_margin_left   = int(PAD_H)
		sb.content_margin_right  = int(PAD_H)
		sb.content_margin_top    = int(PAD_V)
		sb.content_margin_bottom = int(PAD_V)
		panel.add_theme_stylebox_override("panel", sb)

		# 文字
		panel._label = Label.new()
		panel._label.add_theme_color_override("font_color", Color(0.1, 0.1, 0.15))
		panel._label.add_theme_font_size_override("font_size", 40)
		panel._label.text = text
		panel.add_child(panel._label)

		# [shake]
		var re := RegEx.new()
		re.compile("\\[shake=?(\\d*\\.?\\d*)\\]")
		var m := re.search(text)
		if m:
			panel._shake_dur = float(m.get_string(1)) if m.get_string(1) else 0.3
			panel._label.text = re.sub(text, "", true)

		# 尺寸：Label 限制最大宽度让其换行，PanelContainer 自动适配
		panel._label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		panel._label.custom_minimum_size = Vector2(MIN_W, 0)
		# 约束气泡最大宽度
		panel.custom_minimum_size = Vector2(MIN_W, 0)

		return panel
