# SubPageStack — 子页面栈
#
# ★ 全新架构：单 CanvasLayer 渲染
#   子页面直接挂到当前场景的 PageHost 下（不包 CanvasLayer），
#   和主菜单背景/粒子在同一层渲染，没有层叠合成问题。
#
# 用法:
#   GameManager.push_page("res://scenes/ui/difficulty_screen.tscn")
#   var result = await GameManager.page_result

class_name SubPageStack
extends RefCounted

signal page_result(data: Dictionary)

const FADE_DURATION: float = 0.12

var _stack: Array[Node] = []


func is_open() -> bool:
	return not _stack.is_empty()


func push(path: String) -> void:
	# 先黑幕淡入
	await _fade(1.0)

	# 隐藏主菜单内容（如果有 MainContent）
	var scene := _get_scene_root()
	var main_content := _find_main_content(scene)
	if main_content:
		main_content.visible = false

	# 隐藏旧页面
	if _stack.size() > 0:
		var old: Node = _stack[-1]
		if is_instance_valid(old):
			old.visible = false

	# 添加新页面
	var page: Node = _instantiate_page(path)
	_stack.append(page)

	# 黑幕淡出
	await _fade(0.0)


func clear() -> void:
	while _stack.size() > 0:
		var page: Node = _stack.pop_back()
		if is_instance_valid(page):
			page.queue_free()
	# 恢复主菜单内容
	var scene := _get_scene_root()
	var main_content := _find_main_content(scene)
	if main_content:
		main_content.visible = true


func _instantiate_page(path: String) -> Node:
	var page: Node = load(path).instantiate()

	# ★ 不加 CanvasLayer！直接挂到 PageHost 下
	var host := _find_or_create_host(_get_scene_root())
	host.add_child(page)
	page.visible = true

	if page.has_signal("finished"):
		page.finished.connect(_on_page_finished.bind(page), CONNECT_ONE_SHOT)
	if page.has_method(&"_on_enter"):
		page._on_enter()

	return page


func _on_page_finished(data: Dictionary, page_node: Node) -> void:
	if _stack.size() <= 1:
		# 恢复主菜单内容
		var scene := _get_scene_root()
		var main_content := _find_main_content(scene)
		if main_content:
			main_content.visible = true

	for i in range(_stack.size() - 1, -1, -1):
		if _stack[i] == page_node:
			_stack.remove_at(i)
			break
	if is_instance_valid(page_node):
		page_node.queue_free()
	page_result.emit(data)


# ═══ 黑幕过渡（使用场景自身的 FadeRect） ═══

func _fade(target: float) -> void:
	var rect := _get_fade_rect()
	if not rect:
		return
	rect.visible = true
	var tw: Tween = rect.create_tween()
	tw.tween_property(rect, "modulate:a", target, FADE_DURATION)
	await tw.finished
	if target == 0.0:
		rect.visible = false


# ═══ 场景工具 ═══

func _get_scene_root() -> Node:
	var tree: SceneTree = Engine.get_main_loop()
	if tree and tree.current_scene:
		return tree.current_scene
	return null

## 找 PageHost：当前场景下的 Control 容器，子页面挂这里
func _find_or_create_host(scene: Node) -> Node:
	if not scene:
		return null
	# 优先用场景预设的 PageHost
	for child in scene.get_children():
		if child.name == "PageHost":
			return child
	# 没有就创建一个
	var host := Control.new()
	host.name = "PageHost"
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scene.add_child(host)
	return host

## 找 MainContent：当前场景下的主界面内容容器
func _find_main_content(scene: Node) -> Node:
	if not scene:
		return null
	for child in scene.get_children():
		if child.name == "MainContent":
			return child
	return null

## 找 FadeRect：当前场景下的过渡黑幕
func _get_fade_rect() -> ColorRect:
	var scene := _get_scene_root()
	if not scene:
		return null
	for child in scene.get_children():
		if child.name == "FadeRect" and child is ColorRect:
			return child
	return null
