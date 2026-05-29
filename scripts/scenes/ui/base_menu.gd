extends CanvasLayer
class_name BaseMenu

signal item_selected(index: int)
signal menu_back()

const NAV_COOLDOWN: float = 0.08
const ACCEPT_COOLDOWN: float = 0.2

@export var container_path: NodePath
@export var allow_wrap: bool = true
@export var highlight_color: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var normal_color: Color = Color(0.5, 0.5, 0.5, 1.0)
## 锁定选项的颜色（无法选中）
@export var locked_color: Color = Color(0.15, 0.15, 0.15, 1.0)
@export var entrance_stagger: float = 0.0
@export var entrance_duration: float = 0.25
@export var auto_entrance: bool = true

var menu_items: Array[Node] = []
var current_index: int = -1
var input_enabled: bool = true
var _container: Node
var _last_nav_time: float = 0.0
var _last_accept_time: float = 0.0
var _pulse_tween: Tween


# ── 锁定判断（子类可覆写） ──

## 返回 true 意味着该项不可选、被跳过
func _is_item_locked(item_index: int) -> bool:
	var item := menu_items[item_index] if item_index >= 0 and item_index < menu_items.size() else null
	if not item:
		return false
	if item.has_meta("locked"):
		var cond = item.get_meta("locked")
		if cond is Callable:
			return cond.call()
		return true
	return false


## 手动刷新所有选项颜色（外部条件变化导致锁定状态改变时调用）
func refresh_colors(instant: bool = false) -> void:
	for i in menu_items.size():
		var item := menu_items[i]
		if i == current_index:
			_set_item_modulate(item, highlight_color, instant)
		elif _is_item_locked(i):
			_set_item_modulate(item, locked_color, instant)
		else:
			_set_item_modulate(item, normal_color, instant)


# ── 初始化 ──

func _ready():
	layer = 64
	if container_path:
		_container = get_node_or_null(container_path)
	if _container:
		_collect_items()

	if entrance_stagger > 0.0 and not menu_items.is_empty():
		for item in menu_items:
			item.modulate = Color(1, 1, 1, 0)
		current_index = _find_first_unlocked()
		input_enabled = false
	else:
		refresh_colors(true)
		if not menu_items.is_empty():
			# 选第一个未被锁定的项
			current_index = _find_first_unlocked()
			if current_index >= 0:
				select_item(current_index, true)

	_on_ready()

	if entrance_stagger > 0.0 and not menu_items.is_empty():
		if auto_entrance:
			_play_entrance_animation()


func _collect_items():
	menu_items.clear()
	if not _container:
		return
	for child in _container.get_children():
		if _accept_as_menu_item(child):
			menu_items.append(child)


func _accept_as_menu_item(node) -> bool:
	return node is Control or node.has_method("_on_selected")


# ── 输入 ──

func _process(_delta):
	if not input_enabled or menu_items.is_empty():
		return
	var now = Time.get_ticks_msec() / 1000.0

	if Input.is_action_just_pressed("ui_accept"):
		if now - _last_accept_time >= ACCEPT_COOLDOWN:
			_last_accept_time = now
			_accept_current()
		return

	if Input.is_action_just_pressed("ui_cancel"):
		if now - _last_accept_time >= ACCEPT_COOLDOWN:
			_last_accept_time = now
			_on_cancel()
		return

	if Input.is_action_just_pressed("ui_up"):
		_last_nav_time = now
		navigate(-1)
	elif Input.is_action_just_pressed("ui_down"):
		_last_nav_time = now
		navigate(1)
	elif Input.is_action_just_pressed("ui_left"):
		_last_nav_time = now
		navigate(-1)
	elif Input.is_action_just_pressed("ui_right"):
		_last_nav_time = now
		navigate(1)


# ── 导航（跳过锁定项） ──

func navigate(direction: int):
	if menu_items.is_empty():
		return
	
	AudioManager.play_sfx(preload("res://assets/Sound/select.wav"))
	
	var steps := 0
	var new_index := current_index
	while steps < menu_items.size():
		new_index += direction
		if allow_wrap:
			new_index = wrapi(new_index, 0, menu_items.size())
		elif new_index < 0 or new_index >= menu_items.size():
			return
		if not _is_item_locked(new_index):
			break
		steps += 1
	
	if new_index != current_index and not _is_item_locked(new_index):
		select_item(new_index)


func _find_first_unlocked() -> int:
	for i in menu_items.size():
		if not _is_item_locked(i):
			return i
	return -1


# ── 选中 ──

func select_item(index: int, instant: bool = false):
	if index < 0 or index >= menu_items.size():
		return
	var prev = current_index
	if prev >= 0 and prev < menu_items.size():
		_stop_pulse()
		_set_item_modulate(menu_items[prev], _item_color(prev), instant)
	current_index = index
	_set_item_modulate(menu_items[index], highlight_color, instant)
	_start_pulse(menu_items[index])


func _item_color(idx: int) -> Color:
	return locked_color if _is_item_locked(idx) else normal_color


func _set_item_modulate(item: Node, color: Color, instant: bool):
	if not is_instance_valid(item):
		return
	if instant:
		item.modulate = color
		return
	var tw = item.create_tween()
	tw.set_trans(Tween.TRANS_CUBIC)
	tw.set_ease(Tween.EASE_OUT)
	tw.tween_property(item, "modulate", color, 0.12)


# ── 确认（锁定项不触发） ──

func _accept_current():
	if current_index < 0 or current_index >= menu_items.size():
		return
	if _is_item_locked(current_index):
		return
	
	AudioManager.play_sfx(preload("res://assets/Sound/ok.wav"))
	
	var item = menu_items[current_index]
	var selected_index = current_index
	if is_instance_valid(item) and item is CanvasItem:
		input_enabled = false
		var tw = item.create_tween()
		tw.set_trans(Tween.TRANS_BACK)
		tw.set_ease(Tween.EASE_OUT)
		tw.set_loops(3)
		tw.tween_property(item, "modulate", Color(0.8, 0.8, 0.8, 1.0), 0.08)
		tw.tween_property(item, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.08)
		await tw.finished
		input_enabled = true
	item_selected.emit(selected_index)
	_on_item_selected(selected_index)


# ── 入口动画 ──

func _play_entrance_animation():
	for i in menu_items.size():
		var item = menu_items[i]
		if i == current_index:
			item.modulate = Color(highlight_color.r, highlight_color.g, highlight_color.b, 0.0)
		elif _is_item_locked(i):
			item.modulate = Color(locked_color.r, locked_color.g, locked_color.b, 0.0)
		else:
			item.modulate = Color(normal_color.r, normal_color.g, normal_color.b, 0.0)
		if item is Control:
			item.scale = Vector2(0.9, 0.9)

	input_enabled = false

	var tw = create_tween().set_parallel(true)
	for i in menu_items.size():
		var item = menu_items[i]
		var color: Color
		if i == current_index:
			color = highlight_color
		elif _is_item_locked(i):
			color = locked_color
		else:
			color = normal_color
		var delay = i * entrance_stagger
		tw.tween_property(item, "modulate", color, entrance_duration * 0.8).set_delay(delay)
		if item is Control:
			tw.tween_property(item, "scale", Vector2.ONE, entrance_duration).set_delay(delay)\
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	var total = (menu_items.size() - 1) * entrance_stagger + entrance_duration
	tw.tween_callback(_on_entrance_done).set_delay(total)


# ── 高亮脉冲 ──

func _start_pulse(item: Node):
	_stop_pulse()
	if not is_instance_valid(item):
		return
	if item.modulate.a < 0.01:
		return
	var dimmed = Color(
		highlight_color.r * 0.5,
		highlight_color.g * 0.5,
		highlight_color.b * 0.5,
		1.0
	)
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.set_trans(Tween.TRANS_SINE)
	_pulse_tween.tween_property(item, "modulate", highlight_color, 0.3)
	_pulse_tween.tween_property(item, "modulate", dimmed, 0.3)


func _stop_pulse():
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_pulse_tween = null


func _on_entrance_done():
	input_enabled = true
	if current_index >= 0 and current_index < menu_items.size():
		_start_pulse(menu_items[current_index])


func _on_cancel():
	menu_back.emit()
	_on_back()


# ── 子类可覆写 ──

func _on_ready():
	pass

func _on_enter():
	pass

func _on_leave():
	pass

func _on_item_selected(_index: int):
	pass

func _on_back():
	pass
