extends Control
class_name MenuHost
## 菜单栈 —— 管理界面 push/pop，每个界面是独立场景
##
## 用法：
##   var screen = MenuHost.push("res://scenes/ui/difficulty_screen.tscn")
##   MenuHost.pop()  或 screen.finished.emit({})
##
## 被 push 的场景需有 finished(result) 信号（可选继承 MenuScreen）。

signal screen_changed(current: Node, previous: Node)

var _stack: Array[Node] = []
var _root_screen: Node   # 栈底的初始界面（不可 pop）


func _ready() -> void:
	# 第一个子节点作为根界面
	for child in get_children():
		_root_screen = child
		_root_screen.visible = true
		_stack.append(_root_screen)
		if _root_screen.has_method(&"_on_enter"):
			_root_screen._on_enter()
		break


## 推入一个新界面（自动加载场景、实例化、入栈）
func push(scene_path: String) -> Node:
	# 停用当前顶层
	var prev: Node = _stack[-1]
	_set_active(prev, false)
	
	# 加载新场景
	var screen: Node = load(scene_path).instantiate()
	_stack.append(screen)
	add_child(screen)
	screen.visible = true
	
	# 连接 finished（如果提供了）
	_connect_finished(screen)
	
	if screen.has_method(&"_on_enter"):
		screen._on_enter()
	
	screen_changed.emit(screen, prev)
	return screen


## 弹出当前顶层界面
func pop() -> void:
	if _stack.size() <= 1:
		return  # 不能弹出根界面
	
	var screen: Node = _stack.pop_back()
	_disconnect_finished(screen)
	
	if screen.has_method(&"_on_leave"):
		# _on_leave 自己负责动画和 queue_free
		screen._on_leave()
	else:
		screen.queue_free()
	
	# 恢复上一层
	var prev: Node = _stack[-1]
	prev.visible = true
	if prev.has_method(&"_on_activate"):
		prev._on_activate()
	
	screen_changed.emit(prev, screen)


## 弹出到指定界面（含自身）
func pop_to(screen: Node) -> void:
	while _stack.size() > 1 and _stack[-1] != screen:
		_pop_top()
	_connect_finished(screen)


func get_top() -> Node:
	return _stack[-1]


# ── 内部 ──

func _set_active(screen: Node, active: bool) -> void:
	if active:
		screen.visible = true
		if screen.has_method(&"_on_activate"):
			screen._on_activate()
	else:
		if screen.has_method(&"_on_deactivate"):
			screen._on_deactivate()
		screen.visible = false


func _connect_finished(screen: Node) -> void:
	if screen.has_signal(&"finished"):
		if not screen.finished.is_connected(_on_screen_finished):
			screen.finished.connect(_on_screen_finished.bind(screen))


func _disconnect_finished(screen: Node) -> void:
	if screen.has_signal(&"finished") and screen.finished.is_connected(_on_screen_finished):
		screen.finished.disconnect(_on_screen_finished)


func _pop_top() -> void:
	var screen: Node = _stack.pop_back()
	_disconnect_finished(screen)
	screen.queue_free()


func _on_screen_finished(_result, screen: Node) -> void:
	if _stack[-1] == screen:
		pop()
