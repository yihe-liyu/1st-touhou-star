# SubPageStack — 子页面栈
#
# 每个子页面包一层 CanvasLayer(layer=80)，加到 current_scene 下。
# 这样 Control 子节点有正常的渲染上下文，不会出现布局问题。
#
# 用法:
#   GameManager.push_page("res://scenes/ui/difficulty_screen.tscn")
#   var result = await GameManager.page_result

class_name SubPageStack
extends RefCounted

signal page_result(data: Dictionary)

## 子页面的 CanvasLayer 层号（高于主场景 layer=0，低于覆层）
const PAGE_LAYER: int = 80

var _stack: Array[Node] = []  # 栈里存的是 wrapper CanvasLayer


func is_open() -> bool:
	return not _stack.is_empty()


func push(path: String) -> void:
	# 隐藏当前顶层
	if _stack.size() > 0:
		_set_page_active(_stack[-1], false)

	var wrapper: Node = _instantiate_page(path)
	_stack.append(wrapper)


func clear() -> void:
	while _stack.size() > 0:
		var wrapper: Node = _stack.pop_back()
		if is_instance_valid(wrapper):
			wrapper.queue_free()


func _instantiate_page(path: String) -> Node:
	var raw: Node = load(path).instantiate()

	# ★ 关键：Control 包一层 CanvasLayer，添加为 current_scene 的子节点
	var wrapper: Node = raw
	if raw is Control and not raw is CanvasLayer:
		var cl := CanvasLayer.new()
		cl.layer = PAGE_LAYER
		cl.add_child(raw)
		wrapper = cl

	var scene := _get_scene_root()
	if not scene:
		push_error("[SubPageStack] No current scene!")
		raw.queue_free()
		return wrapper

	scene.add_child(wrapper)
	wrapper.visible = true

	# 连接 finished 信号（从内容节点）
	var content: Node = raw
	if content.has_signal("finished"):
		content.finished.connect(_on_page_finished.bind(content), CONNECT_ONE_SHOT)

	# 生命周期
	if content.has_method(&"_on_enter"):
		content._on_enter()

	return wrapper


func _on_page_finished(data: Dictionary, content_node: Node) -> void:
	# 找到 content_node 对应的 wrapper
	for i in range(_stack.size() - 1, -1, -1):
		var wrapper := _stack[i]
		var content: Node = wrapper
		if wrapper is CanvasLayer and wrapper.get_child_count() > 0:
			content = wrapper.get_child(0)
		if content == content_node:
			_stack.remove_at(i)
			# wrapper 会在场景切换或 clear 时清理
			# 但页面已经自己 queue_free 了，所以 wrapper 可以一并清理
			if is_instance_valid(wrapper):
				wrapper.queue_free()
			break

	page_result.emit(data)


func _set_page_active(wrapper: Node, active: bool) -> void:
	if not is_instance_valid(wrapper):
		return
	wrapper.visible = active
	var content: Node = wrapper
	if wrapper is CanvasLayer and wrapper.get_child_count() > 0:
		content = wrapper.get_child(0)
	if not is_instance_valid(content):
		return
	if active:
		if content.has_method(&"_on_activate"):
			content._on_activate()
	else:
		if content.has_method(&"_on_deactivate"):
			content._on_deactivate()


func _get_scene_root() -> Node:
	var tree: SceneTree = Engine.get_main_loop()
	if tree and tree.current_scene:
		return tree.current_scene
	return null
