## 内容工作台 v2 —— 关卡沙盒（真实运行时预览）
##
## 设计（与 v1 模型沙盒的根本区别）：
##   v1：LifecycleNode 纯逻辑模型复刻实体公式（一致性靠"复刻"，会漂移）
##   v2：F6 运行时直接加载真实关卡 —— StageManager + BulletManager + 真实协程
##       幽灵玩家提供自机狙目标；一致性与游戏 100% 相同（跑的就是游戏代码）
##
## 能力：
##   · 播放/暂停/重跑（真实引擎时钟）
##   · 快进跳转（点击时间轴/书签 → 加速跑到目标时刻；真实关卡不支持任意 seek）
##   · 难度切换 / 静音 / 背景开关
##   · 实时状态（时间/子弹数/敌人/Boss/FPS）+ 事件日志
##
## 运行：F6（依赖 autoload），窗口自动设为 1600x1000
extends Control

const VERSION := "v2-sandbox"

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const GHOST_SCRIPT := preload("res://scripts/workbench/ghost_player.gd")
const HITBOX_OVERLAY := preload("res://scripts/workbench/hitbox_overlay.gd")
const BOOKMARK_EXTRACTOR := preload("res://scripts/workbench/bookmark_extractor.gd")
const BOOKMARK_CACHE := preload("res://scripts/workbench/bookmark_cache.gd")
const ENEMY_REG := preload("res://scripts/data/enemy_template_registry.gd")
const REIMU_DATA := preload("res://data/player_data/reimu_data.tres")
const STAGE01 := preload("res://data/stages/stage01/stage_data/stage01.tres")
const STAGE_DEMO := preload("res://data/stage_demo/stage_demo.tres")

const DIFFICULTIES: Array[String] = ["Easy", "Normal", "Hard", "Lunatic"]

var _stage_data: StageData = STAGE01
var _world: Node2D
var _ghost: Player
var _background: Node
var _hitbox_overlay: Node2D  # 实际是 HitboxOverlay（preload，避免类缓存依赖）
var _right_panel: MarginContainer  # 右侧面板（可拖拽调宽）
var _divider: Control
var _drag_divider := false
var _drag_start_x := 0.0
var _drag_start_off := 0.0

# 书签收集（静默快进收集真实事件时刻，缓存到 user://）
var _collecting := false
var _collect_hash := 0
var _collect_max := 45.0   # 收集到该时刻（非符1 开始后足够；Boss 击破后的事件依赖玩家，不收集）
var _collect_times: Array = []
var _collect_attempts := 0  # 防死循环：收集连续失败超限退回静态提取
var _toast := ""           # 短暂提示（收集完成反馈等）
var _toast_t := 0.0
var _auto_bookmarks: Array = []    # 自动收集时刻（当前缓存，编辑后重存用）
var _manual_bookmarks: Array = []  # 人工打点（可编辑，持久化）
var _dialog: CanvasLayer           # 通用弹窗（添加/重命名/确认）
var _bm_menu: PopupMenu            # 书签右键菜单
var _bm_menu_index := -1           # 右键菜单对应的列表项

var _paused := false
var _muted := false
var _show_bg := true
var _speed_idx := 2          # 速度档位索引（SPEEDS）
var _ff_target := -1.0   # 快进目标时刻（-1 = 不快进）
var _prev_time := -1.0   # 时间轴刷新去重
var _log_lines: Array[String] = []

## 播放速度档位（慢放/快进；书签跳转仍用固定 12x）
const SPEEDS: Array[float] = [0.25, 0.5, 1.0, 2.0, 4.0, 8.0, 16.0]

# UI 引用
var _play_btn: Button
var _mute_btn: CheckButton
var _bg_btn: CheckButton
var _stage_sel: OptionButton
var _diff_sel: OptionButton
var _time_label: Label
var _status_label: Label
var _bookmark_list: ItemList
var _current_timeline: Resource   # 当前编辑的 timeline（缓存，避免每次 load 缓存不一致）
var _wave_section: VBoxContainer  # 编排区块（数据关卡才显示）
var _wave_tree: Tree              # 编排表格（数据关卡波次）
var _wave_detail: VBoxContainer   # 选中波次的详情表单容器
var _detail_edits: Array = []     # 详情表单控件（{apply: Callable} 应用时写回）
var _log: RichTextLabel
var _timeline: TimelineBar


# ═══ 初始化 ═══

func _ready() -> void:
	# UI 在暂停/快进时也要活着
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 工作台专用窗口：给右侧面板腾位置（东方框 64,32~832,928 完整可见）
	get_window().size = Vector2i(1600, 1000)
	_build_ui()
	_setup_world()
	_connect_events()
	_load_stage()
	# 初始面板宽度校正（延迟一帧：等窗口/布局就绪，基于实际窗口宽）
	_clamp_panel_width.call_deferred()


func _process(_delta: float) -> void:
	# toast 倒计时
	if _toast_t > 0.0:
		_toast_t -= _delta
		queue_redraw()
	# 书签收集完成检测（静默快进跑完即收）
	if _collecting:
		queue_redraw()  # 遮罩提示持续显示
		var runner := StageManager.current_stage_script()
		if runner == null or runner.game_time() >= _collect_max:
			_finish_collection()
	# 快进到达检测（UI 是 ALWAYS，暂停中也检测）
	if _ff_target >= 0.0:
		var runner := StageManager.current_stage_script()
		if runner == null or runner.game_time() >= _ff_target:
			_stop_fast_forward()
	_update_ui()


func _draw() -> void:
	# 场景底：有背景时让 3D 背景透出，只在东方框外画暗色；无背景时全屏实心
	var has_bg: bool = _show_bg and _background and is_instance_valid(_background)
	var field := Rect2(GameConfig.FIELD_LEFT, GameConfig.FIELD_TOP,
		GameConfig.FIELD_RIGHT - GameConfig.FIELD_LEFT,
		GameConfig.FIELD_BOTTOM - GameConfig.FIELD_TOP)
	if not has_bg:
		draw_rect(Rect2(0, 0, size.x, size.y), Color(0.03, 0.03, 0.05))
	else:
		# 东方框外四块（左上/右上/左下/右下）压暗，框内留给 3D 背景
		draw_rect(Rect2(0, 0, size.x, field.position.y), Color(0.03, 0.03, 0.05))
		draw_rect(Rect2(0, field.end.y, size.x, size.y - field.end.y), Color(0.03, 0.03, 0.05))
		draw_rect(Rect2(0, field.position.y, field.position.x, field.size.y), Color(0.03, 0.03, 0.05))
		draw_rect(Rect2(field.end.x, field.position.y, size.x - field.end.x, field.size.y), Color(0.03, 0.03, 0.05))
	# 东方框边框（保留，提示边界）+ 网格/路径线（仅背景关闭时画，避免浮在 3D 上）
	draw_rect(field, Color(0.35, 0.45, 0.7, 0.5), false, 2.0)
	if not has_bg:
		for x in range(64, 833, 64):
			draw_line(Vector2(x, 32), Vector2(x, 928), Color(1, 1, 1, 0.05))
		for y in range(32, 929, 64):
			draw_line(Vector2(64, y), Vector2(832, y), Color(1, 1, 1, 0.05))
		# 幽灵玩家路径参考（纵向漂移中线）
		draw_line(Vector2(64, 620), Vector2(832, 620), Color(0.3, 0.9, 0.5, 0.15))


func _exit_tree() -> void:
	# 项目规范：断开 autoload 信号连接
	if GameEvents.boss_spawned.is_connected(_on_boss_spawned):
		GameEvents.boss_spawned.disconnect(_on_boss_spawned)
	if GameEvents.phase_start.is_connected(_on_phase_start):
		GameEvents.phase_start.disconnect(_on_phase_start)
	if GameEvents.phase_end.is_connected(_on_phase_end):
		GameEvents.phase_end.disconnect(_on_phase_end)
	if GameEvents.boss_defeated.is_connected(_on_boss_defeated):
		GameEvents.boss_defeated.disconnect(_on_boss_defeated)
	Engine.time_scale = 1.0
	Engine.max_physics_steps_per_frame = 8  # 恢复默认
	AudioManager.set_bgm_pitch(1.0)
	var idx := AudioServer.get_bus_index("Master")
	if idx >= 0:
		AudioServer.set_bus_mute(idx, false)


## 幽灵玩家：实例化真实 player.tscn + 换 GhostPlayer 脚本（继承 Player，类型兼容）
func _setup_world() -> void:
	_world = Node2D.new()
	_world.name = "World"  # StageManager.add_enemy_to_scene / _inject_player_ctx 需要
	# 关键：显式 PAUSABLE！否则继承 root 的 ALWAYS，暂停时敌人照常发弹
	_world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_world)
	# 命中框覆盖层：独立 CanvasLayer + 高 z（> 敌弹 10 / 特效 50），画在子弹之上
	var hl := CanvasLayer.new()
	hl.layer = 5
	add_child(hl)
	_hitbox_overlay = HITBOX_OVERLAY.new()
	_hitbox_overlay.name = "HitboxOverlay"
	_hitbox_overlay.z_index = 60
	hl.add_child(_hitbox_overlay)
	_ghost = PLAYER_SCENE.instantiate()
	_ghost.set_script(GHOST_SCRIPT)
	_ghost.name = "Player"
	_ghost.player_data = REIMU_DATA
	_world.add_child(_ghost)


# ═══ 关卡加载 / 重跑 ═══

func _load_stage() -> void:
	# 停止旧关卡 + 清空
	StageManager.stop_stage()
	BulletManager.clear_all()
	AudioManager.stop_bgm()  # 重跑时 BGM 从头播（play_bgm 有同流防重保护，必须先停）
	# 清 World 残留：退场中的 Boss（_exit_controlled 不 queue_free、已从
	# active_enemies 移除）stop_stage 清不到 → 立即脱离树，避免卡在画面上
	for child in _world.get_children():
		if child != _ghost:
			_world.remove_child(child)
			child.queue_free()
	if _background and is_instance_valid(_background):
		# 立即脱离树（不能只 queue_free 延迟删除）：
		# 旧背景的协程/Tween 会和新背景抢同一个 Camera3D（相机数据错乱）
		remove_child(_background)
		_background.queue_free()
		_background = null
	GameState.restarting = false
	GameState.reset_all()
	if _diff_sel:
		GameState.selected_difficulty = _diff_sel.selected
	# 幽灵复位（重头走路径）
	if _ghost:
		_ghost.reset()
	# 背景：必须先设 current_background（load_stage 会启动背景里的协程脚本）
	if _show_bg and _stage_data.background_scene:
		_background = _stage_data.background_scene.instantiate()
		if _background is StageBackground:
			StageManager.current_background = _background
		# 显式 PAUSABLE：背景演出也随暂停冻结（否则继承 root 的 ALWAYS）
		_background.process_mode = Node.PROCESS_MODE_PAUSABLE
		add_child(_background)
	# 真实加载（跑 stage01.gd 的 Timeline）
	StageManager.load_stage(_stage_data)
	# 时间轴 + 书签（缓存优先，未命中则静默收集真实时刻）
	# 窗口自适应：数据关卡按最大波次时刻；协程关卡默认 60s
	var win := 60.0
	var timeline_data = _get_timeline_data()
	if timeline_data:
		for w in timeline_data.waves:
			win = maxf(win, float(w.get("t", 0.0)) + 10.0)
	_timeline.set_window(win)
	_apply_bookmarks_from_cache()
	# 缓存当前编辑对象（表格/删除/保存共用同一实例，杜绝 load 缓存不一致）
	_current_timeline = _get_timeline_data()
	_refresh_wave_table()
	_prev_time = -1.0
	_log_line("▶ 加载 Stage %d（难度 %s）" % [_stage_data.stage_id, DIFFICULTIES[_diff_sel.selected]])


# ═══ 书签缓存 + 静默收集 ═══

## 书签：缓存优先；未命中（首次/关卡脚本变了）→ 静默快进收集真实事件时刻
func _apply_bookmarks_from_cache() -> void:
	var content_hash := BOOKMARK_CACHE.stage_content_hash(_stage_data)
	var cache: Dictionary = BOOKMARK_CACHE.load(_stage_data.stage_id, content_hash)
	if cache.ok:
		_collect_attempts = 0  # 收集链路已通，重置防循环计数
		_apply_bookmarks(cache.auto, cache.manual)
		_log_line("📖 书签来自缓存（%d 自动 + %d 人工）" % [cache.auto.size(), cache.manual.size()])
	else:
		_manual_bookmarks = cache.manual  # 脚本变了也保留人工打点
		_start_collection(content_hash)


## 显示书签（自动 + 人工合并）
func _apply_bookmarks(auto: Array, manual: Array) -> void:
	_auto_bookmarks = auto.duplicate(true)  # 保存（人工编辑后重存缓存用）
	# 合并排序：全部书签按时间混排；人工书签覆盖同 t 的自动项
	# （自动书签重命名 → 加 manual 但保留 auto → 删除 manual 时自动恢复）
	var items: Array = []
	for bm in manual:
		var t: float = bm.t if bm is Dictionary else float(bm)
		var label: String = bm.label if bm is Dictionary and bm.has("label") else "t=%.1fs" % t
		items.append({"t": t, "label": label, "is_manual": true})
	for bm in auto:
		var t: float = bm.t if bm is Dictionary else float(bm)
		if items.any(func(m: Dictionary) -> bool: return absf(m.t - t) < 0.01):
			continue  # 被人工书签覆盖（改名）
		items.append({"t": t, "label": "t=%.1fs" % t, "is_manual": false})
	items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.t < b.t)
	# 显示（时间轴 + 列表）
	_timeline.clear_bookmarks()
	_bookmark_list.clear()
	for it in items:
		var label: String = ("📌 " + it.label) if it.is_manual else it.label
		_timeline.add_bookmark(it.t, it.label)
		var idx := _bookmark_list.add_item(label)
		_bookmark_list.set_item_metadata(idx, it)


# ═══ 编排表格（数据关卡波次）═══

## 清空容器子节点（VBoxContainer 无 clear()）
func _clear_container(vb: Node) -> void:
	for child in vb.get_children():
		child.queue_free()


## res:// 路径 → user:// 可写副本路径（开发时编辑保存；运行时 res:// 只读）
## 注意：_get_timeline_data 可能已返回 user:// 副本（resource_path 已是 user://）
static func _user_timeline_path(res_path: String) -> String:
	if res_path.begins_with("user://"):
		return res_path
	return "user://" + res_path.trim_prefix("res://")


## 当前关卡的时间线数据（协程关卡返回 null）
## 优先读 user:// 副本（工作台保存的），否则用 res:// 默认
func _get_timeline_data() -> Resource:
	var scr: Script = _stage_data.create_script
	if scr and "TIMELINE" in scr:
		var user_p := _user_timeline_path(scr.TIMELINE.resource_path)
		if FileAccess.file_exists(user_p):
			return load(user_p)
		return scr.TIMELINE
	return null


## 刷新编排表格（数据关卡才显示）
func _refresh_wave_table() -> void:
	if _wave_tree == null:
		return
	_wave_tree.clear()
	_clear_container(_wave_detail)
	var timeline = _current_timeline
	if timeline == null:
		_wave_section.visible = false  # 协程关卡：编排区块整体隐藏
		return
	_wave_section.visible = true
	if timeline.waves.is_empty():
		_wave_tree.visible = false
		_wave_detail.visible = false
		return
	_wave_tree.visible = true
	_wave_detail.visible = true
	var root := _wave_tree.create_item()
	for i in timeline.waves.size():
		var w: Dictionary = timeline.waves[i]
		var item := _wave_tree.create_item(root)
		item.set_text(0, "%.1f" % float(w.get("t", 0.0)))
		item.set_text(1, str(w.get("name", "波次")))
		item.set_text(2, str(w.get("enemy", "")))
		item.set_text(3, str(w.get("count", 1)))
		item.set_text(4, str(w.get("interval", 0.5)))
		item.set_metadata(0, i)


## 新增波次：追加默认波次并选中
func _add_wave() -> void:
	var timeline = _current_timeline
	if timeline == null:
		return
	var max_t := 0.0
	for w in timeline.waves:
		max_t = maxf(max_t, float(w.get("t", 0.0)))
	var names := ENEMY_REG.names()
	timeline.waves.append({
		"t": max_t + 5.0,
		"name": "新波次",
		"enemy": names[0] if not names.is_empty() else "",
		"count": 3,
		"interval": 0.5,
		"params": {},
	})
	_refresh_wave_table()
	var root := _wave_tree.get_root()
	if root and root.get_child_count() > 0:
		root.get_child(root.get_child_count() - 1).select(0)  # 选中新行
	_log_line("➕ 添加波次")


## 删除选中波次（确认后）
func _delete_selected_wave() -> void:
	var item := _wave_tree.get_selected()
	if item == null:
		_log_line("ℹ 先选中要删除的波次")
		return
	var meta: Variant = item.get_metadata(0)
	if typeof(meta) != TYPE_INT:
		return
	var idx: int = meta
	var timeline = _current_timeline
	if timeline == null or idx >= timeline.waves.size():
		return
	var wave_name: String = str(timeline.waves[idx].get("name", "波次"))
	var vb := _make_dialog("🗑 删除波次")
	var msg := Label.new()
	msg.text = "确定删除「%s」？" % wave_name
	vb.add_child(msg)
	_dialog_add_actions(vb, "✓ 删除", func():
		timeline.waves.remove_at(idx)
		_refresh_wave_table()
		_log_line("🗑 删除波次：%s" % wave_name)
	)


## 选中波次 → 详情表单（按字段类型动态生成）
func _on_wave_selected() -> void:
	var item := _wave_tree.get_selected()
	if item == null:
		return
	var meta: Variant = item.get_metadata(0)
	if typeof(meta) != TYPE_INT:
		return  # 根节点/无 metadata（列标题等）
	var idx: int = meta
	var timeline = _current_timeline
	if timeline == null or idx >= timeline.waves.size():
		return
	var w: Dictionary = timeline.waves[idx]
	_detail_edits.clear()
	_clear_container(_wave_detail)
	# 基础字段（可编辑）
	_add_field_edit("t", w, "t", 0.0, 90.0, 0.1, false)
	_add_field_edit("数量", w, "count", 1.0, 60.0, 1.0, true)
	_add_field_edit("间隔", w, "interval", 0.0, 10.0, 0.1, false)
	_add_field_edit("出生x", w, "spawn_x", 0.0, 900.0, 1.0, false)
	_add_field_edit("出生y", w, "spawn_y", -100.0, 1000.0, 1.0, false)
	# 模板参数（按值类型动态生成表单）
	var params: Dictionary = w.get("params", {})
	if not params.is_empty():
		_wave_detail.add_child(_label("── 模板参数 ──"))
		for k in params:
			_add_param_edit(w, k, params[k])
	# 按钮行
	var row := HBoxContainer.new()
	var apply := Button.new()
	apply.text = "✔ 应用"
	apply.pressed.connect(func(): _apply_wave_changes(idx))
	row.add_child(apply)
	var save := Button.new()
	save.text = "💾 保存"
	save.pressed.connect(func(): _save_timeline())
	row.add_child(save)
	_wave_detail.add_child(row)


## 详情表单行：基础字段（SpinBox）
func _add_field_edit(label_text: String, wave: Dictionary, key: String, min_v: float, max_v: float, step: float, as_int: bool) -> void:
	var spin := _make_spin_box(label_text, float(wave.get(key, min_v)), min_v, max_v, step)
	_detail_edits.append({"apply": func():
		if as_int:
			wave[key] = int(spin.value)
		else:
			wave[key] = spin.value
	})


## 模板参数行：按值类型生成控件（float/int/Vector2/bool/String）
func _add_param_edit(wave: Dictionary, key: String, value: Variant) -> void:
	if value is Vector2:
		var h := HBoxContainer.new()
		var l := Label.new()
		l.text = key
		l.custom_minimum_size = Vector2(48, 0)
		h.add_child(l)
		var sx := _mini_spin(value.x, -10000, 10000)
		var sy := _mini_spin(value.y, -10000, 10000)
		h.add_child(sx)
		h.add_child(sy)
		_wave_detail.add_child(h)
		_detail_edits.append({"apply": func():
			wave.params[key] = Vector2(sx.value, sy.value)
		})
	elif value is bool:
		var cb := CheckButton.new()
		cb.text = key
		cb.button_pressed = value
		_wave_detail.add_child(cb)
		_detail_edits.append({"apply": func():
			wave.params[key] = cb.button_pressed
		})
	elif typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
		var as_int := typeof(value) == TYPE_INT
		var spin := _make_spin_box(key, float(value), -100000, 100000, 1.0)
		_detail_edits.append({"apply": func():
			if as_int:
				wave.params[key] = int(spin.value)
			else:
				wave.params[key] = spin.value
		})
	else:
		# 字符串等：LineEdit
		var h := HBoxContainer.new()
		h.add_child(_label(key))
		var line := LineEdit.new()
		line.text = str(value)
		line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(line)
		_wave_detail.add_child(h)
		_detail_edits.append({"apply": func():
			wave.params[key] = line.text
		})


## 通用 SpinBox 行
func _make_spin_box(label_text: String, value: float, min_v: float, max_v: float, step: float) -> SpinBox:
	var h := HBoxContainer.new()
	var l := Label.new()
	l.text = label_text
	l.custom_minimum_size = Vector2(48, 0)
	h.add_child(l)
	var spin := SpinBox.new()
	spin.min_value = min_v
	spin.max_value = max_v
	spin.step = step
	spin.value = value
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(spin)
	_wave_detail.add_child(h)
	return spin


## 参数行内的小 SpinBox（Vector2 用）
func _mini_spin(value: float, min_v: float, max_v: float) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = min_v
	spin.max_value = max_v
	spin.step = 1.0
	spin.value = value
	spin.custom_minimum_size = Vector2(70, 0)
	return spin


## 应用：写回 timeline 数据 → 重跑（WaveStage 读同一资源，新参数生效）
func _apply_wave_changes(idx: int) -> void:
	var timeline = _get_timeline_data()
	if timeline == null or idx >= timeline.waves.size():
		return
	for entry in _detail_edits:
		entry.apply.call()
	_log_line("✔ 应用波次参数 → 重跑")
	_restart()


## 保存：写回 .tres（user:// 可写副本；运行时 res:// 只读）
func _save_timeline() -> void:
	var timeline = _current_timeline
	if timeline == null:
		return
	var user_p := _user_timeline_path(timeline.resource_path)
	DirAccess.make_dir_recursive_absolute(user_p.get_base_dir())
	var err := ResourceSaver.save(timeline, user_p)
	if err == OK:
		_log_line("💾 编排数据已保存 → " + user_p)
	else:
		_log_line("⚠️ 保存失败：%s" % user_p)


## 静默收集：高倍速跑一遍 stage，Timeline 事件触发时记录真实时刻
func _start_collection(content_hash: int) -> void:
	_collect_attempts += 1
	if _collect_attempts > 2:
		# 兜底：收集链路异常（缓存写不进等）→ 退回静态提取，避免无限加速循环
		_log_line("⚠️ 书签收集异常，退回静态提取")
		var bm: Array = BOOKMARK_EXTRACTOR.extract_from_script(_stage_data.create_script)
		var auto: Array = []
		for b in bm:
			auto.append({"t": b.t})
		_apply_bookmarks(auto, _manual_bookmarks)
		return
	_collecting = true
	_collect_hash = content_hash
	_collect_times.clear()
	# 注入收集器（stage_script._tl 已在 load_stage 时创建）
	var script := StageManager.current_stage_script()
	if script and script.get_timeline():
		script.get_timeline().bookmark_collector = _on_collect_event
	# 静默快进
	Engine.time_scale = 40.0
	Engine.max_physics_steps_per_frame = 32
	_apply_audio()
	_log_line("📖 首次运行，静默收集书签（快进到 %.0fs）..." % _collect_max)


func _on_collect_event(t: float) -> void:
	if _collect_times.size() < 3000:
		_collect_times.append(t)


func _finish_collection() -> void:
	_collecting = false
	Engine.time_scale = 1.0
	Engine.max_physics_steps_per_frame = 8
	# 去重排序 + 量化到触发帧：
	# 事件设计时刻（如 1.0+0.1*3 = 1.3000...003）实际在 ceil(t*60)/60 触发，
	# 直接存 t 会导致跳转到 t 时实体未生成（对不齐）
	var times: Array = _collect_times.duplicate()
	times.sort()
	var auto: Array = []
	var last := -INF
	for t in times:
		if t - last < 0.2:
			continue
		last = t
		# 只保留整数秒事件：波内小数时刻浮点边界易对不齐，且跳转价值低
		var t_round := roundf(t)
		if absf(t - t_round) > 0.05:
			continue
		auto.append({"t": t_round})
	BOOKMARK_CACHE.save(_stage_data.stage_id, _collect_hash, auto, _manual_bookmarks)
	_log_line("📖 收集完成：%d 个书签，已缓存" % auto.size())
	_toast = "✅ 书签已生成（%d 个）" % auto.size()
	_toast_t = 1.5
	# 重跑（现在缓存命中 → 正常速度从 0 开始）
	_load_stage()


func _restart() -> void:
	_stop_fast_forward()
	_load_stage()
	_log_line("↺ 重跑")


# ═══ 播放 / 暂停 ═══

func _toggle_play() -> void:
	if _paused:
		_resume()
	else:
		_pause()


func _pause() -> void:
	if _ff_target >= 0.0:
		_stop_fast_forward()
	get_tree().paused = true
	_paused = true
	_apply_audio()
	if _play_btn:
		_play_btn.text = "▶ 播放"
	_log_line("⏸ 暂停")


func _resume() -> void:
	get_tree().paused = false
	_paused = false
	_apply_audio()
	if _play_btn:
		_play_btn.text = "⏸ 暂停"
	_log_line("▶ 继续")


# ═══ 快进跳转（真实关卡不支持任意 seek，只能加速跑到目标）═══

func _jump_to(t: float) -> void:
	# 统一先停现有快进：重置 time_scale / BGM pitch / _ff_target
	# （否则重跑分支或 t≈0 分支会残留 12 倍速 → 数据全乱）
	_stop_fast_forward()
	var runner := StageManager.current_stage_script()
	var cur := runner.game_time() if runner else 0.0
	if t < cur - 0.5:
		# 目标在过去：无法倒带 → 重跑再快进
		_log_line("↺ 目标 %.1fs 在过去（当前 %.1fs），重跑后快进" % [t, cur])
		_load_stage()
	if t <= 0.05:
		return
	_start_fast_forward(t)


func _start_fast_forward(t: float) -> void:
	if _paused:
		_resume()
	_ff_target = t
	Engine.time_scale = 12.0
	# 默认 max_physics_steps_per_frame=8 会丢步（12 步/帧的需求）→ 演出 tween/物理落后
	Engine.max_physics_steps_per_frame = 64
	_apply_audio()
	AudioManager.set_bgm_pitch(Engine.time_scale)  # 音乐跟随快进变速
	_log_line("⏩ 快进到 %.1fs ..." % t)


func _stop_fast_forward() -> void:
	if _ff_target < 0.0:
		return
	var t := _ff_target
	_ff_target = -1.0
	Engine.time_scale = SPEEDS[_speed_idx]  # 恢复到用户设定的速度档位
	Engine.max_physics_steps_per_frame = 8  # 恢复默认
	_apply_audio()
	AudioManager.set_bgm_pitch(1.0)  # 音乐恢复正常
	_log_line("▶ 到达 %.1fs" % t)


## 速度档位切换（慢放 0.25x ~ 快进 16x）
func _on_stage_selected(idx: int) -> void:
	_stage_data = STAGE01 if idx == 0 else STAGE_DEMO
	_restart()
	_log_line("🎚 切换关卡：%s" % (_stage_sel.get_item_text(idx)))


func _on_speed_selected(idx: int) -> void:
	_speed_idx = idx
	if _ff_target < 0.0:
		# 不在书签快进中：直接应用（慢放时 BGM 同步变速）
		Engine.time_scale = SPEEDS[_speed_idx]
		AudioManager.set_bgm_pitch(Engine.time_scale)
		_log_line("⏱ 速度 ×%.2f" % SPEEDS[_speed_idx])


## 命中框绘制（工作台版，轻量：12 段圆 / 一次 draw_rect）
func _apply_audio() -> void:
	var m: bool = _muted or _paused or _ff_target >= 0.0 or _collecting
	var idx := AudioServer.get_bus_index("Master")
	if idx >= 0:
		AudioServer.set_bus_mute(idx, m)


# ═══ UI 刷新 ═══

func _update_ui() -> void:
	var runner := StageManager.current_stage_script()
	var t := runner.game_time() if runner else 0.0
	if _time_label:
		_time_label.text = "t = %.1f s%s" % [t, " ⏩" if _ff_target >= 0.0 else ""]
	if absf(t - _prev_time) >= 0.05:
		_prev_time = t
		if _timeline:
			_timeline.time = t
			_timeline.queue_redraw()
	if _status_label:
		var boss = GameState.get_boss()
		var boss_txt := "—"
		if is_instance_valid(boss):
			boss_txt = "存活"
		_status_label.text = "子弹: %d\n敌人: %d\nBoss: %s\nFPS: %d" % [
			BulletManager.active_bullets.size(),
			GameState.get_active_enemies().size(),
			boss_txt,
			Engine.get_frames_per_second(),
		]


# ═══ 事件日志 ═══

func _connect_events() -> void:
	GameEvents.boss_spawned.connect(_on_boss_spawned)
	GameEvents.phase_start.connect(_on_phase_start)
	GameEvents.phase_end.connect(_on_phase_end)
	GameEvents.boss_defeated.connect(_on_boss_defeated)


func _on_boss_spawned(_boss: Node) -> void:
	_log_line("👑 Boss 登场")


func _on_phase_start(phase: PhaseData) -> void:
	_log_line("🎴 符卡开始：%s" % (phase.name if phase else "？"))


func _on_phase_end(_captured: bool, _bonus: int) -> void:
	_log_line("🏁 符卡结束")


func _on_boss_defeated(_boss: Node) -> void:
	_log_line("💀 Boss 击破")


func _log_line(text: String) -> void:
	if _log == null:
		return
	_log_lines.append(text)
	while _log_lines.size() > 80:
		_log_lines.pop_front()
	_log.text = "\n".join(_log_lines)


# ═══ UI 构建 ═══

func _build_ui() -> void:
	var ui := CanvasLayer.new()
	ui.layer = 10
	ui.name = "UI"
	add_child(ui)

	# ── 右侧面板（工具栏 + 状态 + 书签 + 日志）—— 可拖拽调宽 ──
	# MarginContainer 提供内容左边距（VBox 本身无 padding）
	var margin := MarginContainer.new()
	margin.name = "RightPanel"
	margin.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	# 初始面板宽度：基于视口宽（stretch viewport 模式下布局坐标 = 视口 1280x960，
	# 不是窗口 1600！面板左边缘 = 游戏框右 832 + 16，不遮画面）
	var init_panel_w := minf(752.0, GameConfig.VIEW_WIDTH - GameConfig.FIELD_RIGHT - 16.0)
	margin.offset_left = -init_panel_w  # x ≈ 840
	margin.offset_top = 8.0
	margin.offset_right = -8.0
	margin.offset_bottom = 960.0
	margin.add_theme_constant_override("margin_left", 10)
	ui.add_child(margin)
	_right_panel = margin  # 拖拽改 margin 的 offset
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 6)
	# 面板整体可上下滑动（内容超高时滚动；内部控件改固定高度）
	var right_scroll := ScrollContainer.new()
	right_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_scroll.add_child(right)
	margin.add_child(right_scroll)

	# 拖拽分割条（面板左边缘）
	_divider = ColorRect.new()
	_divider.name = "Divider"
	_divider.color = Color(1, 1, 1, 0.15)
	_divider.mouse_default_cursor_shape = Control.CURSOR_HSIZE
	_divider.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_divider.offset_left = margin.offset_left - 8.0
	_divider.offset_right = margin.offset_left
	_divider.offset_top = 8.0
	_divider.offset_bottom = 928.0
	_divider.gui_input.connect(_on_divider_input)
	ui.add_child(_divider)

	# 标题
	var title := Label.new()
	title.text = "内容工作台 %s" % VERSION
	title.add_theme_font_size_override("font_size", 18)
	right.add_child(title)

	# 工具栏（两行）
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 4)
	right.add_child(grid)

	# 关卡选择
	grid.add_child(_label("关卡"))
	_stage_sel = OptionButton.new()
	_stage_sel.add_item("Stage 1 橡树之庭")
	_stage_sel.add_item("Demo 数据关卡")
	_stage_sel.item_selected.connect(_on_stage_selected)
	grid.add_child(_stage_sel)

	# 难度
	grid.add_child(_label("难度"))
	_diff_sel = OptionButton.new()
	for d in DIFFICULTIES:
		_diff_sel.add_item(d)
	_diff_sel.selected = 1  # Normal
	_diff_sel.item_selected.connect(_on_difficulty_changed)
	grid.add_child(_diff_sel)

	# 播放 / 重跑
	_play_btn = Button.new()
	_play_btn.text = "⏸ 暂停"
	_play_btn.pressed.connect(_toggle_play)
	grid.add_child(_play_btn)
	var restart_btn := Button.new()
	restart_btn.text = "↺ 重跑"
	restart_btn.pressed.connect(_restart)
	grid.add_child(restart_btn)

	# 静音 / 背景
	_mute_btn = CheckButton.new()
	_mute_btn.text = "静音"
	_mute_btn.toggled.connect(_on_mute_toggled)
	grid.add_child(_mute_btn)
	_bg_btn = CheckButton.new()
	_bg_btn.text = "背景"
	_bg_btn.button_pressed = true
	_bg_btn.toggled.connect(_on_bg_toggled)
	grid.add_child(_bg_btn)

	# 命中框（调符卡神器）
	var hitbox_btn := CheckButton.new()
	hitbox_btn.text = "命中框"
	hitbox_btn.toggled.connect(func(on: bool) -> void:
		if _hitbox_overlay:
			_hitbox_overlay.enabled = on
	)
	grid.add_child(hitbox_btn)

	# 播放速度（慢放/快进档位）—— 下拉自带 × 前缀，与命中框配对同行
	var speed_sel := OptionButton.new()
	for s in SPEEDS:
		speed_sel.add_item("×" + str(s))
	speed_sel.selected = _speed_idx
	speed_sel.item_selected.connect(_on_speed_selected)
	grid.add_child(speed_sel)

	# 当前时间
	_time_label = Label.new()
	_time_label.add_theme_font_size_override("font_size", 16)
	right.add_child(_time_label)

	# 状态
	var status_title := _label("── 状态 ──")
	right.add_child(status_title)
	_status_label = Label.new()
	right.add_child(_status_label)

	# 书签
	# ── 编排（数据关卡波次表格 + 详情编辑；协程关卡整体隐藏）──
	_wave_section = VBoxContainer.new()
	_wave_section.add_theme_constant_override("separation", 4)
	right.add_child(_wave_section)
	_wave_section.add_child(_label("── 编排（数据关卡）──"))
	var wave_btns := HBoxContainer.new()
	var add_wave := Button.new()
	add_wave.text = "＋ 波次"
	add_wave.pressed.connect(_add_wave)
	wave_btns.add_child(add_wave)
	var del_wave := Button.new()
	del_wave.text = "🗑 波次"
	del_wave.pressed.connect(_delete_selected_wave)
	wave_btns.add_child(del_wave)
	var save_btn := Button.new()
	save_btn.text = "💾 保存"
	save_btn.pressed.connect(_save_timeline)
	wave_btns.add_child(save_btn)
	_wave_section.add_child(wave_btns)
	_wave_tree = Tree.new()
	_wave_tree.columns = 5
	_wave_tree.custom_minimum_size = Vector2(0, 120)
	_wave_tree.set_column_title(0, "t")
	_wave_tree.set_column_title(1, "波次")
	_wave_tree.set_column_title(2, "敌人")
	_wave_tree.set_column_title(3, "数量")
	_wave_tree.set_column_title(4, "间隔")
	_wave_tree.set_column_expand(1, true)
	_wave_tree.set_column_expand(2, false)
	_wave_tree.set_column_expand(3, false)
	_wave_tree.set_column_expand(4, false)
	_wave_tree.item_selected.connect(_on_wave_selected)
	_wave_section.add_child(_wave_tree)
	# 详情表单包 ScrollContainer：固定高度，内容超高内部滚动
	# （否则表单变高挤压下方书签/日志 → ItemList 滚动重置跳顶）
	var detail_scroll := ScrollContainer.new()
	detail_scroll.custom_minimum_size = Vector2(0, 140)
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_wave_section.add_child(detail_scroll)
	_wave_detail = VBoxContainer.new()
	_wave_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_wave_detail.add_theme_constant_override("separation", 4)
	detail_scroll.add_child(_wave_detail)

	right.add_child(_label("── 书签（点击 = 快进）──"))
	# 编辑按钮行（添加人工书签；删除用列表右键）
	var bm_row := HBoxContainer.new()
	var add_btn := Button.new()
	add_btn.text = "＋ 添加"
	add_btn.pressed.connect(_open_add_bookmark)
	bm_row.add_child(add_btn)
	right.add_child(bm_row)
	# 书签右键菜单（重命名/删除）
	_bm_menu = PopupMenu.new()
	_bm_menu.id_pressed.connect(_on_bm_menu_id_pressed)
	ui.add_child(_bm_menu)
	_bookmark_list = ItemList.new()
	_bookmark_list.custom_minimum_size = Vector2(0, 120)
	_bookmark_list.item_clicked.connect(_on_bookmark_clicked)
	right.add_child(_bookmark_list)

	# 事件日志
	right.add_child(_label("── 事件日志 ──"))
	_log = RichTextLabel.new()
	_log.custom_minimum_size = Vector2(0, 160)
	_log.fit_content = false
	_log.scroll_following = true
	right.add_child(_log)

	# ── 底部时间轴 ──
	_timeline = TimelineBar.new()
	_timeline.name = "Timeline"
	# 时间轴：只横跨游戏框宽度（64~832），贴游戏框下缘（视口 928~960）
	# 不挡游戏框/面板（stretch 视口 1280x960 坐标系）
	_timeline.anchor_left = 0.0
	_timeline.anchor_top = 1.0
	_timeline.anchor_right = 0.0
	_timeline.anchor_bottom = 1.0
	_timeline.offset_left = GameConfig.FIELD_LEFT
	_timeline.offset_right = GameConfig.FIELD_RIGHT
	_timeline.offset_top = -32.0   # y = 928（游戏框下缘）
	_timeline.offset_bottom = 0.0  # y = 960（视口底）
	_timeline.custom_minimum_size = Vector2(0, 32)
	_timeline.jump_to.connect(_jump_to)
	_timeline.right_clicked.connect(_open_add_bookmark)
	ui.add_child(_timeline)


func _on_mute_toggled(on: bool) -> void:
	_muted = on
	_apply_audio()


func _on_bg_toggled(on: bool) -> void:
	_show_bg = on
	_restart()


func _on_difficulty_changed(_i: int) -> void:
	_restart()


## 面板初始宽度校正：左边缘不越过游戏框右缘 + 16（仅初始/窗口变化调用）
func _clamp_panel_width() -> void:
	var win_w := GameConfig.VIEW_WIDTH
	var min_left := -(win_w - GameConfig.FIELD_RIGHT - 16.0)
	if _right_panel and _right_panel.offset_left > min_left:
		_right_panel.offset_left = min_left
		_divider.offset_left = min_left - 8.0
		_divider.offset_right = min_left


## 拖拽分割条：调整右侧面板宽度
func _on_divider_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_drag_divider = event.pressed
		if event.pressed:
			_drag_start_x = (event as InputEventMouseButton).global_position.x
			_drag_start_off = _right_panel.offset_left
	elif event is InputEventMouseMotion and _drag_divider:
		var mm := event as InputEventMouseMotion
		var dx: float = mm.global_position.x - _drag_start_x
		# 宽度范围：面板 300 ~ 窗口-120（offset_left 为负值）
		var min_w := 300.0
		var max_w := GameConfig.VIEW_WIDTH - 120.0
		var new_off := clampf(_drag_start_off + dx, -max_w, -min_w)
		_right_panel.offset_left = new_off
		_divider.offset_left = new_off - 8.0
		_divider.offset_right = new_off


func _label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.modulate = Color(0.7, 0.7, 0.8)
	return l


func _on_bookmark_clicked(index: int, _pos: Vector2, btn: int) -> void:
	if index < 0 or index >= _bookmark_list.item_count:
		return
	var bm: Dictionary = _bookmark_list.get_item_metadata(index)
	if btn == MOUSE_BUTTON_LEFT:
		_jump_to(bm.t)  # 左键跳转
	elif btn == MOUSE_BUTTON_RIGHT:
		_show_bm_menu(index)  # 右键菜单（重命名/删除）


# ═══ 人工书签编辑 ═══

## 编辑后重存缓存（auto 不变，manual 更新）
func _save_bookmarks() -> void:
	var content_hash := BOOKMARK_CACHE.stage_content_hash(_stage_data)
	BOOKMARK_CACHE.save(_stage_data.stage_id, content_hash, _auto_bookmarks, _manual_bookmarks)


func _open_add_bookmark(t: float = -1.0) -> void:
	# 指定时刻（时间轴右键）或当前播放时刻
	var cur: float = t
	if cur < 0.0:
		var runner := StageManager.current_stage_script()
		cur = runner.game_time() if runner else 0.0
	var vb := _make_dialog("📌 添加书签")
	# 时刻输入（默认当前/点击处，可自选）
	var time_row := HBoxContainer.new()
	time_row.add_child(_label("时刻"))
	var time_edit := LineEdit.new()
	time_edit.text = "%.1f" % cur
	time_row.add_child(time_edit)
	vb.add_child(time_row)
	var line := LineEdit.new()
	line.placeholder_text = "名称（如：Boss 最难点）"
	vb.add_child(line)
	_dialog_add_actions(vb, "✓ 添加", func():
		var t_use: float = time_edit.text.to_float()
		if not is_finite(t_use) or t_use < 0.0:
			t_use = cur
		var label := line.text.strip_edges()
		if label.is_empty():
			label = "t=%.1fs" % t_use
		_add_manual_bookmark(t_use, label)
	)
	line.text_submitted.connect(func(_s: String): _dialog_confirm())  # 回车确认
	time_edit.grab_focus()
	time_edit.select_all()


## 通用弹窗骨架：关闭旧弹窗 → 建遮罩+面板 → 返回内容 VBox
func _make_dialog(title: String) -> VBoxContainer:
	_close_dialog()
	var layer := CanvasLayer.new()
	layer.layer = 20
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.4)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -180.0
	panel.offset_right = 180.0
	panel.offset_top = -80.0
	panel.offset_bottom = 80.0
	layer.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	panel.add_child(vb)
	var info := Label.new()
	info.text = title
	vb.add_child(info)
	_dialog = layer
	add_child(layer)
	return vb


## 弹窗按钮行：确认（回调）+ 取消
func _dialog_add_actions(vb: VBoxContainer, ok_text: String, ok_cb: Callable) -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(row)
	var ok := Button.new()
	ok.text = ok_text
	ok.pressed.connect(func():
		ok_cb.call()
		_close_dialog()
	)
	row.add_child(ok)
	var cancel := Button.new()
	cancel.text = "取消"
	cancel.pressed.connect(_close_dialog)
	row.add_child(cancel)


## 当前弹窗的确认按钮（回车触发）
func _dialog_confirm() -> void:
	if _dialog:
		# 找到面板里的确认按钮并触发（简单：全部触发第一个 Button）
		var panel: PanelContainer = _dialog.get_child(1)
		if panel:
			var vb: VBoxContainer = panel.get_child(0)
			for child in vb.get_children():
				if child is HBoxContainer:
					for b in child.get_children():
						if b is Button and b.text.begins_with("✓"):
							b.pressed.emit()
							return


func _close_dialog() -> void:
	if _dialog:
		_dialog.queue_free()
		_dialog = null


func _add_manual_bookmark(t: float, label: String) -> void:
	_manual_bookmarks.append({"t": t, "label": label})
	_save_bookmarks()
	_apply_bookmarks(_auto_bookmarks, _manual_bookmarks)
	_log_line("📌 添加书签：%s" % label)


## 右键菜单（重命名/删除）
func _show_bm_menu(index: int) -> void:
	var meta: Dictionary = _bookmark_list.get_item_metadata(index)
	_bm_menu_index = index
	_bm_menu.clear()
	if meta.get("is_manual", false):
		_bm_menu.add_item("✏️ 重命名")
		_bm_menu.add_item("🗑 删除")
	else:
		_bm_menu.add_item("✏️ 重命名（转为人工）")
		_bm_menu.add_item("🗑 删除")
		_bm_menu.set_item_disabled(1, true)  # 自动书签不可直接删
	_bm_menu.popup(Rect2i(get_viewport().get_mouse_position(), Vector2i()))


func _on_bm_menu_id_pressed(id: int) -> void:
	match id:
		0:
			_open_rename(_bm_menu_index)
		1:
			_open_delete_confirm(_bm_menu_index)


## 重命名弹窗（人工改名；自动书签改名 → 转为人工书签）
func _open_rename(index: int) -> void:
	var meta: Dictionary = _bookmark_list.get_item_metadata(index)
	var is_manual: bool = meta.get("is_manual", false)
	var vb := _make_dialog("✏️ 重命名书签")
	var line := LineEdit.new()
	line.text = meta.label
	vb.add_child(line)
	_dialog_add_actions(vb, "✓ 保存", func():
		var new_label := line.text.strip_edges()
		if new_label.is_empty():
			return
		if is_manual:
			for bm in _manual_bookmarks:
				if absf(bm.t - meta.t) < 0.01 and bm.get("label", "") == meta.label:
					bm.label = new_label
					break
		else:
			# 自动书签重命名 → 加人工书签（保留 auto；显示时人工覆盖，
			# 删除人工书签后自动项自动恢复）
			_manual_bookmarks.append({"t": meta.t, "label": new_label})
		_save_bookmarks()
		_apply_bookmarks(_auto_bookmarks, _manual_bookmarks)
		_log_line("✏️ 重命名书签：%s" % new_label)
	)
	line.text_submitted.connect(func(_s: String): _dialog_confirm())
	line.grab_focus()
	line.select_all()


## 删除确认弹窗
func _open_delete_confirm(index: int) -> void:
	var meta: Dictionary = _bookmark_list.get_item_metadata(index)
	var vb := _make_dialog("🗑 删除书签")
	var msg := Label.new()
	msg.text = "确定删除「%s」？" % meta.label
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(msg)
	_dialog_add_actions(vb, "✓ 删除", func(): _delete_bookmark_at(index))


## 删除指定索引的人工书签（确认后调）
func _delete_bookmark_at(index: int) -> void:
	var meta: Dictionary = _bookmark_list.get_item_metadata(index)
	if not meta.get("is_manual", false):
		_log_line("ℹ 自动书签不可删（改关卡脚本才刷新）")
		return
	for i in range(_manual_bookmarks.size() - 1, -1, -1):
		var bm: Dictionary = _manual_bookmarks[i]
		if absf(bm.t - meta.t) < 0.01 and bm.get("label", "") == meta.label:
			_manual_bookmarks.remove_at(i)
			break
	_save_bookmarks()
	_apply_bookmarks(_auto_bookmarks, _manual_bookmarks)
	_log_line("🗑 删除书签：%s" % meta.label)
