# MenuStack — 菜单栈管理（普通菜单 + overlay 菜单）
class_name MenuStack
extends RefCounted

var _parent: Node
var _on_state_changed: Callable


func setup(parent: Node, on_state_changed: Callable) -> void:
	_parent = parent
	_on_state_changed = on_state_changed


# ── 普通菜单（场景内）──
var _items: Array = []

func push(menu) -> void:
	_items.append(menu)
	if menu.has_method("_on_enter"):
		menu._on_enter()

func pop() -> Node:
	if _items.is_empty():
		return null
	var menu = _items.pop_back()
	if is_instance_valid(menu) and menu.has_method("_on_leave"):
		menu._on_leave()
	return menu

func clear() -> void:
	while not _items.is_empty():
		pop()


# ── Overlay 菜单（暂停/Game Over 等）──
var _overlays: Array = []

func push_overlay(menu: CanvasLayer) -> void:
	_overlays.append(menu)
	_on_state_changed.call(GameManager.AppState.PAUSED)
	menu.process_mode = Node.PROCESS_MODE_ALWAYS
	_parent.get_tree().root.add_child(menu)
	_parent.get_tree().paused = true

func pop_overlay(menu: CanvasLayer) -> void:
	_overlays.erase(menu)
	if is_instance_valid(menu):
		menu.queue_free()
	if _overlays.is_empty():
		_on_state_changed.call(GameManager.AppState.PLAYING)
		_parent.get_tree().paused = false


func is_overlay_open() -> bool:
	return not _overlays.is_empty()


func is_menu_open() -> bool:
	return not _items.is_empty()
