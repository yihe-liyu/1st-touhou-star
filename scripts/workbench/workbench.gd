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
var _inspector: VBoxContainer  # 参数面板（右）

# ── 初始化 ──

func _ready() -> void:
	if _timeline == null:
		_build_ui()
	_build_demo()
	_focus = _root
	_canvas.focus = _focus
	_timeline.focus = _focus
	_refresh_tree()
	_playing = true  # 打开自动播放：一进来就看到弹幕生长（否则像"不发射"）
	_update_controls()
	_update_inspector()
	_timeline.queue_redraw()


func _process(delta: float) -> void:
	if _playing:
		# 关键：限制 delta（编辑器 @tool 模式下 delta 可能暴涨到几百秒
		# → 时间瞬间跳完 → 弹幕秒死 → 画面空/卡"不发射"）
		var dt := minf(delta, 0.05)
		_time += dt * _speed
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
	# 重置（方案 A）：时间归零；播放状态保持不变
	print("[WB] RESET START")
	_time = 0.0
	if _focus:
		_focus.simulate_to(0.0)
		print("[WB] RESET simulated: local_t=", _focus.local_time, " children=", _focus.children.size())
	if _timeline:
		_timeline.time = 0.0
		_timeline.queue_redraw()
	_refresh_tree.call_deferred()
	print("[WB] RESET DONE")


# ── 演示树：发射器 → 生成子弹 → 死亡 ──

func _build_demo() -> void:
	# 树根：把发射器声明为生成计划（确定性重跑时自动重建）
	var root := WorkbenchDemoRoot.new()
	var emitter := WorkbenchDemoEmitter.new()
	root.child_plan = [{"t": 0.0, "node": emitter}]  # 立即出生：重置后 0.5s 就有子弹
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
	# 拖尾设置
	var trail_check := CheckButton.new()
	trail_check.text = "拖尾"
	trail_check.button_pressed = true
	trail_check.toggled.connect(_on_trail_toggled)
	toolbar.add_child(trail_check)
	var trail_slider := HSlider.new()
	trail_slider.min_value = 0
	trail_slider.max_value = 60
	trail_slider.step = 1
	trail_slider.value = 24
	trail_slider.custom_minimum_size = Vector2(80, 0)
	trail_slider.value_changed.connect(_on_trail_length)
	toolbar.add_child(trail_slider)

	# 中部：树 + 画布
	var mid := HSplitContainer.new()
	mid.name = "Mid"
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(mid)
	_tree_ui = Tree.new()
	_tree_ui.custom_minimum_size = Vector2(140, 0)
	_tree_ui.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tree_ui.item_selected.connect(_on_tree_selected)
	mid.add_child(_tree_ui)
	_canvas = CanvasScript.new()
	_canvas.custom_minimum_size = Vector2(320, 320)  # 弹性：小窗口也能显示
	_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_child(_canvas)
	# 参数面板（右）
	_inspector = VBoxContainer.new()
	_inspector.name = "Inspector"
	_inspector.custom_minimum_size = Vector2(150, 0)
	_inspector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_child(_inspector)

	# 底部：时间轴
	_timeline = TimelineBarScript.new()
	_timeline.name = "Timeline"
	_timeline.custom_minimum_size = Vector2(0, 48)
	_timeline.time_seeked.connect(_on_time_seeked)  # 时间线只 seek；主对象切换来自左侧树
	_timeline.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_timeline)


func _toggle_play() -> void:
	_playing = not _playing
	_update_controls()


func _cycle_speed() -> void:
	# 轮转速度：×1 → ×2 → ×0.5 → ×1 ...
	var speeds := [1.0, 2.0, 0.5]
	var idx: int = speeds.find(_speed)
	_speed = speeds[(idx + 1) % speeds.size()] if idx >= 0 else 1.0
	_speed_btn.text = "速度 ×" + str(_speed)


func _on_trail_toggled(on: bool) -> void:
	if _canvas:
		_canvas.show_trail = on

func _on_trail_length(v: float) -> void:
	if _canvas:
		_canvas.trail_length = int(v)

func _update_controls() -> void:
	if _play_btn:
		_play_btn.text = "⏸ 暂停" if _playing else "▶ 播放"


func _update_time_label() -> void:
	if _time_label:
		var state := "" if _playing else " ⏸"
		_time_label.text = "t=%.2fs%s" % [_time, state]


# ── 聚焦/导航 ──

var _last_seek_ms: int = 0  # 拖动节流（全量重放较贵，拖动中限制频率）

## 点击/拖动时间线 = seek：时间跳到该处，全树状态更新到对应时刻
func _on_time_seeked(t: float) -> void:
	if _focus == null:
		return
	_time = t  # 播放头位置总是即时更新
	var now := Time.get_ticks_msec()
	if now - _last_seek_ms < 50:  # ~20Hz 节流：拖动流畅不卡
		return
	_last_seek_ms = now
	_focus.simulate_to(t)  # 确定性重放（seek）
	_refresh_tree.call_deferred()
	_update_inspector()


func _on_node_selected(node: LifecycleNode) -> void:
	# 防重入：同一节点（如信号风暴/重复点击）只刷新不重置时间
	if node == _focus:
		_refresh_tree.call_deferred()
		_update_inspector()
		return
	# 时间轴切到该对象的局部时间线（锚点语义）
	# 注意：保留 _time（不归零）——切换主对象后画布立刻显示
	# 该时刻的完整状态，不会变成空画面
	_focus = node
	_focus.simulate_to(_time)
	if _canvas:
		_canvas.focus = _focus
	_breadcrumb.text = _breadcrumb_path(node)
	_refresh_tree.call_deferred()
	_timeline.focus = _focus
	_timeline.time = _time
	_timeline.queue_redraw()
	_update_inspector()


func _breadcrumb_path(node: LifecycleNode) -> String:
	var script_ref: Script = node.get_script() as Script
	var parts: Array = [script_ref.resource_path.get_file().get_basename()]
	var n: LifecycleNode = node
	while n.parent:
		n = n.parent
		var pref: Script = n.get_script() as Script
		parts.push_front(pref.resource_path.get_file().get_basename())
	return " › ".join(parts)


# ── 参数面板 ──

## 显示选中节点的生命周期属性
func _update_inspector() -> void:
	if _inspector == null:
		return
	for child in _inspector.get_children():
		child.queue_free()
	if _focus == null:
		return
	var script_ref: Script = _focus.get_script() as Script
	var title := Label.new()
	title.text = "■ " + script_ref.resource_path.get_file().get_basename()
	title.add_theme_font_size_override("font_size", 16)
	_inspector.add_child(title)
	_add_inspector_row("锚点（出生）", "%.2fs" % _focus.anchor)
	_add_inspector_row("局部时间", "%.2fs" % _focus.local_time)
	_add_inspector_row("世界时间", "%.2fs" % _focus.world_time())
	_add_inspector_row("状态", "▶ 存活" if _focus.alive else "✖ 死亡")
	_add_inspector_row("子对象数", str(_focus.children.size()))
	_add_inspector_row("子对象", _child_summary(_focus))
	# 行为事件（生成计划时刻）
	var plan: Array = _focus._spawn_plan()
	if plan.size() > 0:
		var times: Array = []
		for ev in plan:
			times.append("%.1f" % ev.t)
		_add_inspector_row("行为事件", "t=" + "、".join(times))


func _add_inspector_row(key: String, value: String) -> void:
	var row := HBoxContainer.new()
	var k := Label.new()
	k.text = key
	k.custom_minimum_size = Vector2(90, 0)
	k.modulate = Color(0.7, 0.7, 0.8)
	var v := Label.new()
	v.text = value
	v.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART  # 长文本换行，不撑宽
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(k)
	row.add_child(v)
	_inspector.add_child(row)


func _child_summary(node: LifecycleNode) -> String:
	# 截断：最多列 5 个，避免超长文本撑爆面板（画布被挤出！）
	var names: Array = []
	for child in node.children:
		if names.size() >= 5:
			break
		var ref: Script = child.get_script() as Script
		names.append(ref.resource_path.get_file().get_basename())
	var s: String = "、".join(names)
	if node.children.size() > 5:
		s += "… 等 %d 个" % node.children.size()
	return s if names.size() > 0 else "—"


# ── 生命周期树 UI ──

var _tree_sig: String = ""

## 树刷新：结构签名变化才重建（实体生成/死亡才刷 → 播放不卡）
func _refresh_tree() -> void:
	if _tree_ui == null:
		return
	var sig := _tree_signature(_focus)
	if sig == _tree_sig:
		return  # 结构没变：跳过重建（性能）
	_tree_sig = sig
	_tree_ui.clear()
	var root_item := _tree_ui.create_item()
	root_item.set_text(0, _node_label(_focus))
	root_item.set_metadata(0, _focus)
	# 注意：不要 select()——Tree.select 触发 item_selected → 信号循环崩溃！
	_add_tree_children(root_item, _focus)


## 树结构签名：对象节点（非实体）+ 存活数 + 局部时间（量化）
func _tree_signature(node: LifecycleNode) -> String:
	var parts: Array = [str(int(node.local_time * 10)), str(node.alive)]
	for child in node.children:
		if not child.is_entity():
			parts.append(_tree_signature(child))
	return "|".join(parts)


func _add_tree_children(parent_item: TreeItem, node: LifecycleNode) -> void:
	for child in node.children:
		if child.is_entity():
			continue  # 实体（子弹）不进编排树
		var item := _tree_ui.create_item(parent_item)
		item.set_text(0, _node_label(child))
		item.set_metadata(0, child)
		_add_tree_children(item, child)


func _node_label(node: LifecycleNode) -> String:
	var script_ref: Script = node.get_script() as Script
	var label: String = script_ref.resource_path.get_file().get_basename()
	var state: String = "▶" if node.alive else "✖"
	var events: Array = node._behavior_events()
	var beh: String = ""
	if events.size() > 0:
		beh = "  [%d 行为]" % events.size()
	return "%s %s (t=%.1f)%s" % [state, label, node.local_time, beh]


func _on_tree_selected() -> void:
	var item := _tree_ui.get_selected()
	if item:
		var node: LifecycleNode = item.get_metadata(0)
		if node == _focus:
			return  # 已是主对象：忽略（防信号循环）
		# Tree 在鼠标选中事件期间禁止 clear/create → 延迟到事件结束后
		_on_node_selected.call_deferred(node)
