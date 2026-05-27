extends CanvasLayer
class_name BaseMenu

signal item_selected(index: int)
signal menu_back()

const NAV_COOLDOWN: float = 0.08
const ACCEPT_COOLDOWN: float = 0.2

## 菜单项容器 NodePath（如 ^"Container"）
@export var container_path: NodePath
## 是否允许首尾循环
@export var allow_wrap: bool = true
## 选中项高亮颜色（未选中项恢复为白色）
@export var highlight_color: Color = Color(1.0, 1.0, 1.0, 1.0)
## 未选中项的颜色
@export var normal_color: Color = Color(0.5, 0.5, 0.5, 1.0)
## 选项逐个弹出的间隔时间（0 = 禁用入口动画）
@export var entrance_stagger: float = 0.0
## 每个选项的弹出时长
@export var entrance_duration: float = 0.25
## 是否在 _ready 后自动开始入场动画
## 设为 false 可让子类自行控制时机（如等 logo 动画完）
@export var auto_entrance: bool = true

var menu_items: Array[Node] = []
var current_index: int = -1
var input_enabled: bool = true
var _container: Node
var _last_nav_time: float = 0.0
var _last_accept_time: float = 0.0

func _ready():
	layer = 64
	if container_path:
		_container = get_node_or_null(container_path)
	if _container:
		_collect_items()

	if entrance_stagger > 0.0 and not menu_items.is_empty():
		# 入口动画模式：先全隐藏，由 _play_entrance_animation() 处理
		for item in menu_items:
			item.modulate = Color(1, 1, 1, 0)
	else:
		# 没有入口动画，正常设置颜色
		for item in menu_items:
			_set_item_modulate(item, normal_color, true)
		if not menu_items.is_empty():
			select_item(0, true)

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

func navigate(direction: int):
	if menu_items.is_empty():
		return
	var new_index = current_index + direction
	if allow_wrap:
		new_index = wrapi(new_index, 0, menu_items.size())
	else:
		new_index = clampi(new_index, 0, menu_items.size() - 1)
	if new_index != current_index:
		select_item(new_index)

func select_item(index: int, instant: bool = false):
	if index < 0 or index >= menu_items.size():
		return
	var prev = current_index
	if prev >= 0 and prev < menu_items.size():
		_set_item_modulate(menu_items[prev], normal_color, instant)
	current_index = index
	_set_item_modulate(menu_items[index], highlight_color, instant)

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

func _accept_current():
	if current_index < 0 or current_index >= menu_items.size():
		return
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
	# 每个选项从正确颜色开始（只改透明度），最后没有颜色 snap
	for i in menu_items.size():
		var item = menu_items[i]
		var color = highlight_color if i == current_index else normal_color
		item.modulate = Color(color.r, color.g, color.b, 0.0)
		if item is Control:
			item.scale = Vector2(0.9, 0.9)

	input_enabled = false

	var tw = create_tween().set_parallel(true)
	for i in menu_items.size():
		var item = menu_items[i]
		var color = highlight_color if i == current_index else normal_color
		var delay = i * entrance_stagger
		tw.tween_property(item, "modulate", color, entrance_duration * 0.8).set_delay(delay)
		if item is Control:
			tw.tween_property(item, "scale", Vector2.ONE, entrance_duration).set_delay(delay)\
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# 动画完成后只恢复输入
	var total = (menu_items.size() - 1) * entrance_stagger + entrance_duration
	tw.tween_callback(func(): input_enabled = true).set_delay(total)

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
