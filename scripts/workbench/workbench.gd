## 内容工作台主场景（@tool）
## 生命周期树 + 预览画布 + 时间轴条带（播放/暂停/拖动/聚焦）
## 编辑器里打开即见；F6 运行可交互
@tool
extends Control

const TimelineBarScript = preload("res://scripts/workbench/ui/timeline_bar.gd")
const CanvasScript = preload("res://scripts/workbench/ui/workbench_canvas.gd")

var _root: LifecycleNode   # 树根（当前演示）
var _focus: LifecycleNode  # 聚焦对象（时间轴锚点）
var _time: float = 0.0
var _playing: bool = false
var _speed: float = 1.0

var _canvas: Control
var _tree_ui: Tree
var _timeline: Control
var _breadcrumb: Label
var _time_label: Label
var _play_btn: Button
var _speed_btn: Button

# ── 初始化 ──

func _ready() -> void:
	if _timeline == null:
		_build_ui()
	_build_demo()
	_focus = _root
	_canvas.focus = _focus
	_timeline.focus = _focus
	_refresh_tree()
	if Engine.is_editor_hint():
		_playing = false  # 编辑器编辑模式默认暂停
	else:
		_playing = true
	_update_controls()
	_timeline.queue_redraw()


func _process(delta: float) -> void:
	if _playing:
		_time += delta * _speed
		_simulate()
	if _canvas:
		_canvas.queue_redraw()
	if _timeline:
		_timeline.time = _time
		_timeline.queue_redraw()
	_update_time_label()


# ── 模拟 ──

func _simulate() -> void:
	if _focus == null:
		return
	_focus.advance_to(_time)  # 播放 = 增量推进（高效）
	_refresh_tree()


func _reset() -> void:
	_time = 0.0
	if _focus:
		_focus.simulate_to(0.0)  # 重置 = 全量重放
	_refresh_tree()


# ── 演示树：发射器 → 生成子弹 → 死亡 ──

func _build_demo() -> void:
	# 树根：把发射器声明为生成计划（确定性重跑时自动重建）
	var root := WorkbenchDemoRoot.new()
	var emitter := WorkbenchDemoEmitter.new()
	root.child_plan = [{"t": 1.0, "node": emitter}]
	_root = root
	# 初始显示 t=3s 的状态
	_root.simulate_to(3.0)
	_time = 3.0






# ── UI 构建 ──

func _build_ui() -> void:
	# 工具栏
	var toolbar := HBoxContainer.new()
	toolbar.name = "Toolbar"
	add_child(toolbar)
	_play_btn = Button.new()
	_play_btn.text = "▶ 播放"
	_play_btn.pressed.connect(_toggle_play)
	toolbar.add_child(_play_btn)
	var reset := Button.new()
	reset.text = "↺ 重置"
	reset.pressed.connect(_reset)
	toolbar.add_child(reset)
	_speed_btn = Button.new()
	_speed_btn.text = "速度 ×1"
	_speed_btn.pressed.connect(_cycle_speed)
	toolbar.add_child(_speed_btn)
	_breadcrumb = Label.new()
	_breadcrumb.text = "Stage"
	toolbar.add_child(_breadcrumb)
	_time_label = Label.new()
	toolbar.add_child(_time_label)

	# 中部：树 + 画布
	var mid := HSplitContainer.new()
	mid.name = "Mid"
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(mid)
	_tree_ui = Tree.new()
	_tree_ui.custom_minimum_size = Vector2(220, 0)
	_tree_ui.item_selected.connect(_on_tree_selected)
	mid.add_child(_tree_ui)
	_canvas = CanvasScript.new()
	_canvas.custom_minimum_size = Vector2(560, 420)
	mid.add_child(_canvas)

	# 底部：时间轴
	_timeline = TimelineBarScript.new()
	_timeline.name = "Timeline"
	_timeline.custom_minimum_size = Vector2(0, 48)
	_timeline.node_selected.connect(_on_node_selected)
	_timeline.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_timeline)


func _toggle_play() -> void:
	_playing = not _playing
	_update_controls()


func _cycle_speed() -> void:
	_speed = [1.0, 2.0, 0.5][[1.0, 2.0, 0.5].find(_speed, 0)] if false else ([1.0, 2.0, 0.5][[1.0, 2.0, 0.5].find(_speed)] if [1.0, 2.0, 0.5].has(_speed) else 1.0)
	_speed_btn.text = "速度 ×%g" % _speed


func _update_controls() -> void:
	if _play_btn:
		_play_btn.text = "⏸ 暂停" if _playing else "▶ 播放"


func _update_time_label() -> void:
	if _time_label:
		_time_label.text = "t=%.2fs" % _time


# ── 聚焦/导航 ──

func _on_node_selected(node: LifecycleNode) -> void:
	# 时间轴切到该对象的局部时间线（锚点语义）
	_focus = node
	_time = 0.0
	_focus.simulate_to(0.0)
	if _canvas:
		_canvas.focus = _focus
	_breadcrumb.text = _breadcrumb_path(node)
	_refresh_tree.call_deferred()
	_timeline.focus = _focus
	_timeline.time = 0.0
	_timeline.queue_redraw()


func _breadcrumb_path(node: LifecycleNode) -> String:
	var script_ref: Script = node.get_script() as Script
	var parts: Array = [script_ref.resource_path.get_file().get_basename()]
	var n: LifecycleNode = node
	while n.parent:
		n = n.parent
		var pref: Script = n.get_script() as Script
		parts.push_front(pref.resource_path.get_file().get_basename())
	return " › ".join(parts)


# ── 生命周期树 UI ──

func _refresh_tree() -> void:
	if _tree_ui == null:
		return
	_tree_ui.clear()
	var root_item := _tree_ui.create_item()
	root_item.set_text(0, _node_label(_focus))
	root_item.set_metadata(0, _focus)
	_add_tree_children(root_item, _focus)


func _add_tree_children(parent_item: TreeItem, node: LifecycleNode) -> void:
	for child in node.children:
		var item := _tree_ui.create_item(parent_item)
		item.set_text(0, _node_label(child))
		item.set_metadata(0, child)
		_add_tree_children(item, child)


func _node_label(node: LifecycleNode) -> String:
	var script_ref: Script = node.get_script() as Script
	var label: String = script_ref.resource_path.get_file().get_basename()
	var state: String = "▶" if node.alive else "✖"
	return "%s %s (t=%.1f)" % [state, label, node.local_time]


func _on_tree_selected() -> void:
	var item := _tree_ui.get_selected()
	if item:
		var node: LifecycleNode = item.get_metadata(0)
		# Tree 在鼠标选中事件期间禁止 clear/create → 延迟到事件结束后
		_on_node_selected.call_deferred(node)
