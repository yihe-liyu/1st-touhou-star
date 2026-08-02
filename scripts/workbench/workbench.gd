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
const REIMU_DATA := preload("res://data/player_data/reimu_data.tres")
const STAGE01 := preload("res://data/stages/stage01/stage_data/stage01.tres")

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
var _add_dialog: CanvasLayer      # 添加书签弹窗引用

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
	_timeline.set_window(60.0)
	_apply_bookmarks_from_cache()
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
	_timeline.clear_bookmarks()
	_bookmark_list.clear()
	for bm in auto:
		var t: float = bm.t if bm is Dictionary else float(bm)
		var label := "t=%.1fs" % t
		_timeline.add_bookmark(t, label)
		var idx := _bookmark_list.add_item(label)
		_bookmark_list.set_item_metadata(idx, {"t": t, "label": label, "is_manual": false})
	for bm in manual:
		var t: float = bm.t if bm is Dictionary else float(bm)
		var label: String = bm.label if bm is Dictionary and bm.has("label") else "t=%.1fs" % t
		_timeline.add_bookmark(t, label)
		var idx := _bookmark_list.add_item("📌 " + label)  # 人工标记
		_bookmark_list.set_item_metadata(idx, {"t": t, "label": label, "is_manual": true})


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
	margin.offset_bottom = 928.0
	margin.add_theme_constant_override("margin_left", 10)
	ui.add_child(margin)
	_right_panel = margin  # 拖拽改 margin 的 offset
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 6)
	margin.add_child(right)

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
	_stage_sel.disabled = true  # 目前只有一个关卡
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
	right.add_child(_label("── 书签（点击 = 快进）──"))
	# 编辑按钮行（添加人工书签；删除用列表右键）
	var bm_row := HBoxContainer.new()
	var add_btn := Button.new()
	add_btn.text = "＋ 添加"
	add_btn.pressed.connect(_open_add_bookmark)
	bm_row.add_child(add_btn)
	right.add_child(bm_row)
	_bookmark_list = ItemList.new()
	_bookmark_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_bookmark_list.custom_minimum_size = Vector2(0, 120)
	_bookmark_list.item_clicked.connect(_on_bookmark_clicked)
	right.add_child(_bookmark_list)

	# 事件日志
	right.add_child(_label("── 事件日志 ──"))
	_log = RichTextLabel.new()
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log.custom_minimum_size = Vector2(0, 160)
	_log.fit_content = false
	_log.scroll_following = true
	right.add_child(_log)

	# ── 底部时间轴 ──
	_timeline = TimelineBar.new()
	_timeline.name = "Timeline"
	_timeline.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_timeline.offset_left = 8.0
	_timeline.offset_right = -8.0
	_timeline.offset_top = -64.0   # y ≈ 936
	_timeline.offset_bottom = -4.0 # y ≈ 996
	_timeline.custom_minimum_size = Vector2(0, 56)
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
		_delete_bookmark_at(index)  # 右键直接删除（无需先选中）


# ═══ 人工书签编辑 ═══

## 编辑后重存缓存（auto 不变，manual 更新）
func _save_bookmarks() -> void:
	var content_hash := BOOKMARK_CACHE.stage_content_hash(_stage_data)
	BOOKMARK_CACHE.save(_stage_data.stage_id, content_hash, _auto_bookmarks, _manual_bookmarks)


func _open_add_bookmark(t: float = -1.0) -> void:
	if _add_dialog:
		return
	# 指定时刻（时间轴右键）或当前播放时刻
	var cur: float = t
	if cur < 0.0:
		var runner := StageManager.current_stage_script()
		cur = runner.game_time() if runner else 0.0
	# 弹窗（CanvasLayer + 遮罩 + 面板）
	var layer := CanvasLayer.new()
	layer.layer = 20
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.4)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -170.0
	panel.offset_right = 170.0
	panel.offset_top = -90.0
	panel.offset_bottom = 90.0
	layer.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	panel.add_child(vb)
	var info := Label.new()
	info.text = "📌 添加书签"
	vb.add_child(info)
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
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(row)
	var ok := Button.new()
	ok.text = "✓ 添加"
	row.add_child(ok)
	var cancel := Button.new()
	cancel.text = "取消"
	row.add_child(cancel)
	ok.pressed.connect(func():
		var t_use: float = time_edit.text.to_float()
		if not is_finite(t_use) or t_use < 0.0:
			t_use = cur
		var label := line.text.strip_edges()
		if label.is_empty():
			label = "t=%.1fs" % t_use
		_add_manual_bookmark(t_use, label)
		_close_add_dialog()
	)
	cancel.pressed.connect(_close_add_dialog)
	line.text_submitted.connect(func(_t: String): ok.pressed.emit())  # 回车确认
	add_child(layer)
	_add_dialog = layer
	time_edit.grab_focus()
	time_edit.select_all()


func _close_add_dialog() -> void:
	if _add_dialog:
		_add_dialog.queue_free()
		_add_dialog = null


func _add_manual_bookmark(t: float, label: String) -> void:
	_manual_bookmarks.append({"t": t, "label": label})
	_save_bookmarks()
	_apply_bookmarks(_auto_bookmarks, _manual_bookmarks)
	_log_line("📌 添加书签：%s" % label)


## 删除指定索引的人工书签（右键直接删）
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


