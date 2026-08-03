## 内容工作台 —— 关卡沙盒（真实运行时预览）+ 编排编辑器（组件化版）
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
##   · 编排编辑（数据关卡）：波次表格 + 详情表单 + 增删保存（user:// 副本）
##
## 结构（2026-08 组件化重构）：
##   workbench.gd        —— 主控制器：装配 + 关卡生命周期 + 状态路由
##   playback_bar.gd     —— 播放控制行（信号 → 主控制器）
##   status_bar.gd       —— 实时状态显示（主控制器每帧喂数据）
##   event_log.gd        —— 事件日志（自连 GameEvents）
##   wave_table.gd       —— 波次表格（已有）
##   wave_form.gd        —— 波次详情表单（动态生成 + 写回 + 信号）
##   bookmark_panel.gd   —— 书签列表 + 编辑弹窗（数据自持 + data_changed 信号）
##   dialog.gd           —— 通用弹窗宿主
##   ui_common.gd        —— 控件工厂
##   布局框架在 scenes/workbench.tscn（容器/锚点/分割条/时间轴）
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
const _WAVE_TABLE_SCRIPT = preload("res://scripts/workbench/ui/wave_table.gd")

const DIFFICULTIES: Array[String] = ["Easy", "Normal", "Hard", "Lunatic"]
## 播放速度档位（慢放/快进；书签跳转仍用固定 12x）
const SPEEDS: Array[float] = [0.25, 0.5, 1.0, 2.0, 4.0, 8.0, 16.0]

# ═══ .tscn 框架节点 ═══
@onready var _right_panel: MarginContainer = %RightPanel
@onready var _divider: ColorRect = %Divider
@onready var _timeline: TimelineBar = %Timeline
@onready var _stage_grid: GridContainer = %StageGrid
@onready var _wave_section: VBoxContainer = %WaveSection
# 符卡编辑（Boss 阶段）
var _spell_section: VBoxContainer
var _spell_form_box: VBoxContainer
var _phase_sel: OptionButton
var _add_boss_btn: Button
@onready var _world: Node2D = $World

# ═══ 组件（代码挂载到 .tscn 槽位）═══
var _playback: PlaybackBar
var _status: StatusBar
var _log_view: EventLog
var _bookmarks: BookmarkPanel
var _wave_table                    # WaveTable（preload，避免类缓存依赖）
var _wave_form: WaveForm
var _dialog: DialogHost

# 关卡状态
var _stage_data: StageData = STAGE01
var _ghost: Player
var _background: Node
var _hitbox_overlay: Node2D  # 实际是 HitboxOverlay（preload，避免类缓存依赖）

# 面板拖拽
var _drag_divider := false
var _drag_start_x := 0.0
var _drag_start_off := 0.0
# 详情表单高度拖拽
var _form_drag := false
var _form_drag_start_y := 0.0
var _form_drag_start_h := 0.0

# 书签收集（静默快进收集真实事件时刻，缓存到 user://）
var _collecting := false
var _collect_hash := 0
var _collect_max := 45.0   # 收集到该时刻（非符1 开始后足够；Boss 击破后的事件依赖玩家，不收集）
var _collect_times: Array = []
var _collect_attempts := 0  # 防死循环：收集连续失败超限退回静态提取
var _skip_next_collection := false  # 收集完成后重跑跳过（防 hash 异常导致连环收集）
var _toast := ""           # 短暂提示（收集完成反馈等）
var _toast_t := 0.0
var _auto_bookmarks: Array = []    # 自动收集时刻（当前缓存，编辑后重存用）
var _manual_bookmarks: Array = []  # 人工打点（可编辑，持久化）

# 播放/编辑状态
var _paused := false
var _muted := false
var _show_bg := true
var _speed_idx := 2          # 速度档位索引（SPEEDS）
var _ff_target := -1.0   # 快进目标时刻（-1 = 不快进）
var _prev_time := -1.0   # 时间轴刷新去重
var _current_timeline: Resource   # 当前编辑的 timeline（缓存，避免每次 load 缓存不一致）
# 统一编辑模型：选中敌波编辑波次（wave）/ 选中 Boss 编辑符卡（boss）
var _edit_mode := "wave"

# UI 控件（关卡/难度下拉）
var _stage_sel: OptionButton
var _diff_sel: OptionButton


# ═══ 初始化 ═══

func _ready() -> void:
	# UI 在暂停/快进时也要活着
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 主题：东方风深色面板（中文字体 + 卡片 + 控件样式）
	theme = WorkbenchTheme.build()
	%Title.add_theme_color_override("font_color", WorkbenchUI.ACCENT)
	# 工作台专用窗口：纵向 1:1（1600x960 对 1280x960 视口纵向无拉伸 → 文字清晰）
	# 横向 1.25x 给右侧面板腾位置（东方框 64,32~832,928 完整可见）
	get_window().size = Vector2i(1600, 960)
	%Title.text = "内容工作台 %s" % VERSION
	_build_ui()
	_setup_world()
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
	Engine.time_scale = 1.0
	Engine.max_physics_steps_per_frame = 8  # 恢复默认
	AudioManager.set_bgm_pitch(1.0)
	var idx := AudioServer.get_bus_index("Master")
	if idx >= 0:
		AudioServer.set_bus_mute(idx, false)


# ═══ 装配 ═══

func _build_ui() -> void:
	# ── 关卡/难度（.tscn 的 StageGrid，代码填控件）──
	_stage_sel = OptionButton.new()
	_stage_sel.add_item("Stage 1 橡树之庭")
	_stage_sel.add_item("Demo 数据关卡")
	_stage_sel.item_selected.connect(_on_stage_selected)
	_stage_grid.add_child(WorkbenchUI.label("关卡"))
	_stage_grid.add_child(_stage_sel)
	_diff_sel = OptionButton.new()
	for d in DIFFICULTIES:
		_diff_sel.add_item(d)
	_diff_sel.selected = 1  # Normal
	_diff_sel.item_selected.connect(_on_difficulty_changed)
	_stage_grid.add_child(WorkbenchUI.label("难度"))
	_stage_grid.add_child(_diff_sel)

	# ── 播放控制（纯视图，信号驱动）──
	_playback = PlaybackBar.new()
	_playback.play_toggled.connect(_toggle_play)
	_playback.restart_requested.connect(_restart)
	_playback.mute_toggled.connect(_on_mute_toggled)
	_playback.bg_toggled.connect(_on_bg_toggled)
	_playback.hitbox_toggled.connect(func(on: bool):
		if _hitbox_overlay:
			_hitbox_overlay.enabled = on
	)
	_playback.speed_selected.connect(_on_speed_selected)
	%PlaybackSlot.add_child(_playback)

	# ── 状态显示 ──
	_status = StatusBar.new()
	%StatusSlot.add_child(_status)

	# ── 编排（数据关卡波次表格 + 详情编辑；协程关卡整体隐藏）──
	_wave_section.add_child(WorkbenchUI.section_title("── 编排（数据关卡）──"))
	# 操作栏：应用 / ＋波次 / 🗑波次 / 💾保存（统一等宽对齐）
	var wave_btns := HBoxContainer.new()
	wave_btns.add_theme_constant_override("separation", 4)
	var apply_btn := Button.new()
	apply_btn.text = "应用"
	apply_btn.pressed.connect(_apply_wave)
	wave_btns.add_child(apply_btn)
	var add_wave := Button.new()
	add_wave.text = "添加波次"
	add_wave.pressed.connect(_add_wave)
	wave_btns.add_child(add_wave)
	var del_wave := Button.new()
	del_wave.text = "删除波次"
	del_wave.pressed.connect(_delete_selected_wave)
	wave_btns.add_child(del_wave)
	var save_btn := Button.new()
	save_btn.text = "保存"
	save_btn.pressed.connect(_save_timeline)
	wave_btns.add_child(save_btn)
	# ＋ Boss（数据关卡且无 Boss 时可用：添加 Boss + 默认阶段）
	_add_boss_btn = Button.new()
	_add_boss_btn.text = "＋ Boss"
	_add_boss_btn.pressed.connect(_add_boss)
	_add_boss_btn.visible = false
	wave_btns.add_child(_add_boss_btn)
	# 五个按钮等宽均分，视觉对齐
	for b in [apply_btn, add_wave, del_wave, save_btn, _add_boss_btn]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 28)
	_wave_section.add_child(wave_btns)
	# 波次表：自制行列表格（列头+网格线+选中高亮）
	_wave_table = _WAVE_TABLE_SCRIPT.new()
	_wave_table.custom_minimum_size = Vector2(0, 140)
	_wave_table.wave_selected.connect(_on_wave_selected)
	_wave_section.add_child(_wave_table)
	# 详情表单（自带滚动容器，固定高度防挤布局）
	_wave_form = WaveForm.new()
	_wave_form.applied.connect(_on_wave_applied)
	_wave_section.add_child(_wave_form)
	# 高度拖拽条：在表单底部（拖底边 = 底边跟手变长，符合直觉）
	var form_divider := ColorRect.new()
	form_divider.custom_minimum_size = Vector2(0, 5)
	form_divider.color = Color(1, 1, 1, 0.12)
	form_divider.mouse_default_cursor_shape = Control.CURSOR_VSIZE
	form_divider.gui_input.connect(func(ev: InputEvent): _on_form_divider_input(ev))
	_wave_section.add_child(form_divider)
	# ── 符卡编辑（Boss 阶段：数据 + 脚本 + 参数）──
	# 独立于波次编辑区（统一编辑模型：选 Boss 时替换显示）
	_spell_section = VBoxContainer.new()
	_spell_section.add_theme_constant_override("separation", 4)
	_spell_form_box = VBoxContainer.new()
	_spell_form_box.add_theme_constant_override("separation", 4)
	_spell_section.add_child(_spell_form_box)
	# 挂到右侧面板（WaveSection 之后），不与波次编辑嵌套
	%WaveSection.get_parent().add_child(_spell_section)
	_update_edit_mode()

	# ── 书签（数据自持，编辑后 data_changed 回主控制器持久化）──
	_bookmarks = BookmarkPanel.new()
	_bookmarks.jump_requested.connect(_jump_to)
	_bookmarks.data_changed.connect(_on_bookmarks_changed)
	_bookmarks.log_requested.connect(_log_line)
	%BookmarkSlot.add_child(_bookmarks)

	# ── 日志（自连 GameEvents）──
	_log_view = EventLog.new()
	%LogSlot.add_child(_log_view)

	# ── 时间轴（.tscn 节点）──
	_timeline.jump_to.connect(_jump_to)
	_timeline.right_clicked.connect(_bookmarks.open_add)
	_timeline.wave_selected.connect(_on_wave_selected)
	_timeline.wave_moved.connect(_on_wave_moved)
	_timeline.boss_selected.connect(_on_timeline_boss_selected)
	_timeline.boss_moved.connect(_on_timeline_boss_moved)

	# ── 通用弹窗（删除波次确认等）──
	_dialog = DialogHost.new()
	$UI.add_child(_dialog)

	# ── 分割条拖拽（.tscn 节点）──
	_divider.gui_input.connect(_on_divider_input)


## 幽灵玩家：实例化真实 player.tscn + 换 GhostPlayer 脚本（继承 Player，类型兼容）
func _setup_world() -> void:
	# World 节点在 .tscn（显式 PAUSABLE！否则继承 root 的 ALWAYS，暂停时敌人照常发弹）
	# 命中框覆盖层：独立 CanvasLayer + 高 z（> 敌弹 10 / 特效 50），画在子弹之上
	_hitbox_overlay = HITBOX_OVERLAY.new()
	_hitbox_overlay.name = "HitboxOverlay"
	_hitbox_overlay.z_index = 60
	$HitboxLayer.add_child(_hitbox_overlay)
	_ghost = PLAYER_SCENE.instantiate()
	_ghost.set_script(GHOST_SCRIPT)
	_ghost.name = "Player"
	_ghost.player_data = REIMU_DATA
	_world.add_child(_ghost)


# ═══ 关卡加载 / 重跑 ═══

## 加载关卡（start_from >= 0 = 从该时刻续跑，数据关卡专用）
func _load_stage(start_from: float = -1.0) -> void:
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
	StageManager.load_stage(_stage_data, start_from)
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
	_refresh_spell_section()
	# Boss 条带（时间轴第 0 行）；宽度 = 阶段总时长
	var bs := -1.0
	var bdur := 0.0
	if _stage_data and _stage_data.boss:
		bs = _stage_data.boss_time
		for p in _stage_data.boss.phases:
			if p:
				bdur += p.time_limit
		bdur = maxf(bdur, 1.0)
	_timeline.set_boss(bs, bdur)
	_edit_mode = "wave"  # 每次加载默认敌波编辑
	_timeline.set_boss_selected(false)
	_update_edit_mode()
	_prev_time = -1.0
	_log_line("▶ 加载 Stage %d（难度 %s）" % [_stage_data.stage_id, DIFFICULTIES[_diff_sel.selected]])


# ═══ 书签缓存 + 静默收集 ═══

## 书签：缓存优先；未命中（首次/关卡脚本变了）→ 静默快进收集真实事件时刻
func _apply_bookmarks_from_cache() -> void:
	# 协程关卡（无 TIMELINE 数据）：直接静态提取，不做运行时收集
	# （否则每次进工作台 Stage1 都收集，切走即打断 → 缓存永不建立 → 每次重复）
	if not _is_data_stage():
		_auto_bookmarks = _static_extract()
		_bookmarks.set_bookmarks(_auto_bookmarks, _manual_bookmarks)
		_refresh_timeline_bookmarks()
		_log_line("📖 书签（静态提取 %d 个）" % _auto_bookmarks.size())
		return
	# 刚收集完成的重跑：直接应用已收集结果，不再收集
	if _skip_next_collection:
		_skip_next_collection = false
		_bookmarks.set_bookmarks(_auto_bookmarks, _manual_bookmarks)
		_refresh_timeline_bookmarks()
		return
	var content_hash := BOOKMARK_CACHE.stage_content_hash(_stage_data)
	var cache: Dictionary = BOOKMARK_CACHE.load(_stage_data.stage_id, content_hash)
	if cache.ok:
		_collect_attempts = 0  # 收集链路已通，重置防循环计数
		_auto_bookmarks = cache.auto
		_manual_bookmarks = cache.manual
		_bookmarks.set_bookmarks(_auto_bookmarks, _manual_bookmarks)
		_refresh_timeline_bookmarks()
		_log_line("📖 书签来自缓存（%d 自动 + %d 人工）" % [_auto_bookmarks.size(), _manual_bookmarks.size()])
	else:
		_manual_bookmarks = cache.manual  # 脚本变了也保留人工打点
		# 区分收集原因（帮助用户判断是否预期行为）
		if BOOKMARK_CACHE.has_cache(_stage_data.stage_id):
			_log_line("🔄 关卡数据/脚本已变化，重新收集书签...")
		else:
			_log_line("📖 首次运行，静默收集书签（快进到 %.0fs）..." % _collect_max)
		_start_collection(content_hash)


## 是否数据关卡（有 StageTimeline 数据，可运行时收集书签）
func _is_data_stage() -> bool:
	return _get_timeline_data() != null


## 静态提取书签（协程关卡/收集兜底）：扫描 tl.at() 时刻
func _static_extract() -> Array:
	var bm: Array = BOOKMARK_EXTRACTOR.extract_from_script(_stage_data.create_script)
	var auto: Array = []
	for b in bm:
		auto.append({"t": b.t})
	return auto


## 时间轴书签刷新（自动 + 人工合并；与 BookmarkPanel 同源静态合并函数）
func _refresh_timeline_bookmarks() -> void:
	_timeline.clear_bookmarks()
	for it in BookmarkPanel.merged(_auto_bookmarks, _manual_bookmarks):
		_timeline.add_bookmark(it.t, it.label)


## 静默收集：高倍速跑一遍 stage，Timeline 事件触发时记录真实时刻
func _start_collection(content_hash: int) -> void:
	if _collecting:
		return  # 防重入：已有收集在进行（切换关卡时旧收集未完成）
	_collect_attempts += 1
	if _collect_attempts > 2:
		# 兜底：收集链路异常（缓存写不进等）→ 退回静态提取，避免无限加速循环
		_log_line("⚠️ 书签收集异常，退回静态提取")
		_auto_bookmarks = _static_extract()
		_bookmarks.set_bookmarks(_auto_bookmarks, _manual_bookmarks)
		_refresh_timeline_bookmarks()
		_skip_next_collection = true  # 本会话不再自动收集
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
		# 量化到 0.1s：保留 0.5s 网格等非整数锚点（工作台拖拽波次产生，
		# 旧逻辑只留整数秒会把这些波次的书签全部过滤 → 书签列表空）
		# 浮点边界（如 1.3000...003）吸附到 0.1 后跳转也能对齐
		auto.append({"t": snappedf(t, 0.1)})
	BOOKMARK_CACHE.save(_stage_data.stage_id, _collect_hash, auto, _manual_bookmarks)
	_auto_bookmarks = auto
	_bookmarks.set_bookmarks(_auto_bookmarks, _manual_bookmarks)
	_refresh_timeline_bookmarks()
	_log_line("📖 收集完成：%d 个书签，已缓存" % auto.size())
	_toast = "✅ 书签已生成（%d 个）" % auto.size()
	_toast_t = 1.5
	_skip_next_collection = true  # 重跑直接应用结果，不再收集（防 hash 异常连环收集）
	# 重跑（现在缓存命中 → 正常速度从 0 开始）
	_load_stage()


## 书签被编辑（BookmarkPanel data_changed）→ 持久化 + 刷时间轴
func _on_bookmarks_changed(auto: Array, manual: Array) -> void:
	_auto_bookmarks = auto.duplicate(true)
	_manual_bookmarks = manual.duplicate(true)
	var content_hash := BOOKMARK_CACHE.stage_content_hash(_stage_data)
	BOOKMARK_CACHE.save(_stage_data.stage_id, content_hash, _auto_bookmarks, _manual_bookmarks)
	_refresh_timeline_bookmarks()


# ═══ 编排表格（数据关卡波次）═══

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


## 刷新编排表格（数据关卡才显示）+ 同步时间轴波次数据
func _refresh_wave_table() -> void:
	_wave_form.clear()
	var timeline = _current_timeline
	_timeline.set_waves(timeline.waves if timeline else [])
	# ＋Boss/＋阶段：数据关卡常驻显示（无 Boss 添加，有 Boss 追加阶段）
	var has_boss: bool = _stage_data != null and _stage_data.boss != null
	_add_boss_btn.visible = timeline != null
	_add_boss_btn.text = "＋ 阶段" if has_boss else "＋ Boss"
	if timeline == null:
		_wave_section.visible = false  # 协程关卡：编排区块整体隐藏
		return
	_wave_section.visible = true
	if timeline.waves.is_empty():
		_wave_table.visible = false
		_wave_form.visible = false
		return
	_wave_table.visible = true
	_wave_form.visible = true
	_wave_table.setup(timeline)


## 应用选中波次参数（上边栏按钮；表单在 WaveForm 内已写回）
func _apply_wave() -> void:
	if _wave_form._idx < 0:
		_log_line("ℹ 先选中要应用的波次")
		return
	_wave_form.apply_changes()


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
	_wave_table.select_row(_wave_table.row_count() - 1)  # 选中新行
	_log_line("➕ 添加波次")


## 删除选中波次（确认后）
func _delete_selected_wave() -> void:
	var idx: int = _wave_table.selected_idx()
	if idx < 0:
		_log_line("ℹ 先选中要删除的波次")
		return
	var timeline = _current_timeline
	if timeline == null or idx >= timeline.waves.size():
		return
	var wave_name: String = str(timeline.waves[idx].get("name", ""))
	if wave_name.is_empty():
		# 无名字时给足信息：波次#索引 (t=时刻)
		wave_name = "波次#%d (t=%.1fs)" % [idx, float(timeline.waves[idx].get("t", 0.0))]
	var vb := _dialog.open("🗑 删除波次")
	var msg := Label.new()
	msg.text = "确定删除「%s」？" % wave_name
	vb.add_child(msg)
	_dialog.add_actions("确定", func():
		timeline.waves.remove_at(idx)
		_refresh_wave_table()
		_log_line("🗑 删除波次：%s" % wave_name)
	)


	# 选中波次 → 详情表单（WaveForm 按字段类型动态生成）
	# 表格/时间轴双向联动：任何一方的选中都同步另一方高亮
func _on_wave_selected(idx: int) -> void:
	_edit_mode = "wave"
	_timeline.set_boss_selected(false)
	_update_edit_mode()
	_wave_form.show_wave(_current_timeline, idx)
	_timeline.selected_wave = idx
	_wave_table.select_row(idx)


## 时间轴拖拽松手：t 已写回共享引用 → 刷新表格并恢复选中
func _on_wave_moved(idx: int, t: float) -> void:
	var name_str := ""
	if _current_timeline and idx >= 0 and idx < _current_timeline.waves.size():
		name_str = str(_current_timeline.waves[idx].get("name", ""))
	_refresh_wave_table()
	_wave_table.select_row(idx)
	_log_line("↔ 波次「%s」→ t=%.1fs" % [name_str, t])


## 应用：WaveForm 已写回 timeline 数据 → 从该波次前 3 秒续跑验证
## （不需要从头跑：改参即看效果的核心循环）
func _on_wave_applied(idx: int) -> void:
	var t_from := -1.0
	if _current_timeline and idx >= 0 and idx < _current_timeline.waves.size():
		t_from = float(_current_timeline.waves[idx].get("t", 0.0))
	if t_from >= 0.0:
		_log_line("✔ 应用波次参数 → 从 %.1fs 续跑" % t_from)
		_restart_from(t_from)
	else:
		_log_line("✔ 应用波次参数 → 重跑")
		_restart()


## 从指定关卡时刻续跑（数据关卡：起点前已结束的波次跳过）
func _restart_from(t: float) -> void:
	_stop_fast_forward()
	_load_stage(t)
	_log_line("▶ 从 %.1fs 续跑" % t)


## 保存：先同步表单值（没点应用的改动也保存）→ 写回 .tres（user:// 可写副本）
func _save_timeline() -> void:
	var timeline = _current_timeline
	if timeline == null:
		return
	_wave_form.flush()  # 表单当前值写回数据，避免保存旧值
	var user_p := _user_timeline_path(timeline.resource_path)
	DirAccess.make_dir_recursive_absolute(user_p.get_base_dir())
	var err := ResourceSaver.save(timeline, user_p)
	if err == OK:
		_log_line("💾 编排数据已保存 → " + user_p)
	else:
		_log_line("⚠️ 保存失败：%s" % user_p)


# ═══ 播放 / 暂停 / 快进 ═══

func _restart() -> void:
	_cancel_collection()
	_stop_fast_forward()
	_load_stage()
	_log_line("↺ 重跑")


## 取消进行中的书签收集（切换关卡/重跑时调用，避免旧收集与新流程重叠）
func _cancel_collection() -> void:
	if _collecting:
		_collecting = false
		Engine.time_scale = SPEEDS[_speed_idx]
		Engine.max_physics_steps_per_frame = 8
		_apply_audio()
		_collect_attempts = 0  # 打断的收集不计入防循环计数


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
	_playback.set_playing(false)
	_apply_audio()
	_log_line("⏸ 暂停")


func _resume() -> void:
	get_tree().paused = false
	_paused = false
	_playback.set_playing(true)
	_apply_audio()
	_log_line("▶ 继续")


## 快进跳转（真实关卡不支持任意 seek，只能加速跑到目标）
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


# ═══ 选项回调 ═══

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


func _on_mute_toggled(on: bool) -> void:
	_muted = on
	_apply_audio()


func _on_bg_toggled(on: bool) -> void:
	_show_bg = on
	_restart()


func _on_difficulty_changed(_i: int) -> void:
	_restart()


func _apply_audio() -> void:
	var m: bool = _muted or _paused or _ff_target >= 0.0 or _collecting
	var idx := AudioServer.get_bus_index("Master")
	if idx >= 0:
		AudioServer.set_bus_mute(idx, m)


# ═══ UI 刷新 / 日志 ═══

func _update_ui() -> void:
	var runner := StageManager.current_stage_script()
	var t := runner.game_time() if runner else 0.0
	_status.set_time(t, _ff_target >= 0.0)
	if absf(t - _prev_time) >= 0.05:
		_prev_time = t
		_timeline.time = t
		_timeline.queue_redraw()
	var boss = GameState.get_boss()
	_status.set_status(
		BulletManager.active_bullets.size(),
		GameState.get_active_enemies().size(),
		is_instance_valid(boss),
		int(Engine.get_frames_per_second()))


func _log_line(text: String) -> void:
	if _log_view:
		_log_view.log_line(text)


# ═══ 右侧面板拖拽 ═══

## 面板初始宽度校正：左边缘不越过游戏框右缘 + 16（仅初始/窗口变化调用）
func _clamp_panel_width() -> void:
	var win_w := GameConfig.VIEW_WIDTH
	var min_left := -(win_w - GameConfig.FIELD_RIGHT - 16.0)
	if _right_panel and _right_panel.offset_left > min_left:
		_right_panel.offset_left = min_left
		_divider.offset_left = min_left - 8.0
		_divider.offset_right = min_left


## 详情表单高度拖拽：上下拖动调整可视区高度（80~400px，内部滚动跟随）
func _on_form_divider_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_form_drag = event.pressed
		if event.pressed:
			_form_drag_start_y = (event as InputEventMouseButton).global_position.y
			_form_drag_start_h = _wave_form.custom_minimum_size.y
	elif event is InputEventMouseMotion and _form_drag:
		var mm := event as InputEventMouseMotion
		var dy: float = mm.global_position.y - _form_drag_start_y
		_wave_form.custom_minimum_size.y = clampf(_form_drag_start_h + dy, 80.0, 400.0)


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


# ═══ 符卡编辑（Boss 阶段：数据 + 脚本 + 参数）═══

## 统一编辑模型：编辑区互斥（选敌波 → 波次表单 / 选 Boss → 符卡表单）
func _update_edit_mode() -> void:
	if _edit_mode == "boss":
		_wave_section.visible = false
		_spell_section.visible = _stage_data != null and _stage_data.boss != null \
			and _stage_data.boss.phases.size() > 0
	else:
		_spell_section.visible = false
		_wave_section.visible = _get_timeline_data() != null  # 数据关卡才显示


## 时间轴选中 Boss → 编辑符卡（替换敌波编辑）
func _on_timeline_boss_selected() -> void:
	_edit_mode = "boss"
	_refresh_spell_section()
	_update_edit_mode()
	_log_line("🎴 选中 Boss，编辑符卡阶段")


## Boss 条带拖拽松手 → 写回 boss_time（保存后生效）
func _on_timeline_boss_moved(t: float) -> void:
	if _stage_data:
		_stage_data.boss_time = t
	_log_line("↔ Boss 出现时刻 → t=%.1fs（保存后生效）" % t)


## 添加 Boss/阶段：无 Boss 创建默认 Boss + 非符阶段；有 Boss 追加阶段
func _add_boss() -> void:
	if _stage_data == null:
		return
	if _stage_data.boss != null:
		_add_phase()  # 按钮文字已是"＋ 阶段"
		return
	var boss := BossData.new()
	boss.boss_name = "新 Boss"
	boss.phases.append(_make_default_phase(0))
	_stage_data.boss = boss
	_stage_data.boss_time = 20.0
	var err := ResourceSaver.save(_stage_data, _stage_data.resource_path)
	_refresh_wave_table()
	_refresh_spell_section()
	_update_edit_mode()
	if err == OK:
		_log_line("➕ 添加 Boss：%s（时间轴上拖红色条带调出现时刻）" % boss.boss_name)
	else:
		_log_line("⚠️ Boss 保存失败：%d" % err)


## 添加阶段：Boss 追加一个默认阶段并保存
func _add_phase() -> void:
	var boss: BossData = _stage_data.boss if _stage_data else null
	if boss == null:
		return
	boss.phases.append(_make_default_phase(boss.phases.size()))
	var err := ResourceSaver.save(_stage_data, _stage_data.resource_path)
	_refresh_spell_section()
	if err == OK:
		_log_line("➕ 添加阶段（共 %d 个，击破后自动进入下一阶段）" % boss.phases.size())
	else:
		_log_line("⚠️ 阶段保存失败：%d" % err)


## 默认阶段（名字/血量/时限 + 挂首个移动/弹幕脚本）
func _make_default_phase(idx: int) -> PhaseData:
	var phase := PhaseData.new()
	phase.name = "非符 %d" % (idx + 1)
	phase.hp = 1000
	phase.time_limit = 30.0
	phase.bonus = 0
	var m_names := BossScriptRegistry.move_names()
	if not m_names.is_empty():
		phase.move_script = BossScriptRegistry.move_script(str(m_names[0]))
	var s_names := BossScriptRegistry.shoot_names()
	if not s_names.is_empty():
		phase.shoot_script = BossScriptRegistry.shoot_script(str(s_names[0]))
	return phase


## "＋ 阶段"按钮（符卡区 Boss 行）
func _add_phase_btn() -> Button:
	var b := Button.new()
	b.text = "＋ 阶段"
	b.add_theme_font_size_override("font_size", 12)
	b.pressed.connect(_add_phase)
	return b


## 刷新符卡编辑区（清空重建，避免重复累积）
func _refresh_spell_section() -> void:
	for c in _spell_section.get_children():
		c.queue_free()
	_phase_sel = null
	var boss: BossData = _stage_data.boss if _stage_data else null
	if boss == null or boss.phases.is_empty():
		_spell_section.visible = false
		return
	_spell_section.visible = (_edit_mode == "boss")  # 由编辑模式控制
	_spell_section.add_child(WorkbenchUI.section_title("── 符卡（Boss 阶段）──"))
	var boss_row := HBoxContainer.new()
	boss_row.add_theme_constant_override("separation", 6)
	boss_row.add_child(WorkbenchUI.param_label("Boss"))
	var boss_l := Label.new()
	boss_l.text = boss.boss_name
	boss_row.add_child(boss_l)
	boss_row.add_child(_add_phase_btn())
	_spell_section.add_child(boss_row)
	_phase_sel = OptionButton.new()
	_phase_sel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for i in boss.phases.size():
		var p: PhaseData = boss.phases[i]
		_phase_sel.add_item("%d: %s" % [i, p.name if not p.name.is_empty() else "非符"])
	_phase_sel.item_selected.connect(func(_i: int): _refresh_spell_form())
	_spell_section.add_child(_phase_sel)
	# 重建表单容器（上一轮清空后需重建）
	_spell_form_box = VBoxContainer.new()
	_spell_form_box.add_theme_constant_override("separation", 4)
	_spell_section.add_child(_spell_form_box)
	_refresh_spell_form()


## 重建选中阶段的编辑表单
func _refresh_spell_form() -> void:
	for c in _spell_form_box.get_children():
		c.queue_free()
	var boss: BossData = _stage_data.boss if _stage_data else null
	if boss == null or _phase_sel == null or _phase_sel.selected < 0 \
			or _phase_sel.selected >= boss.phases.size():
		return
	var phase: PhaseData = boss.phases[_phase_sel.selected]
	var fields := {}
	# 名字
	var name_edit := LineEdit.new()
	name_edit.text = phase.name
	name_edit.custom_minimum_size = Vector2(140, 0)
	fields["name"] = name_edit
	_spell_form_box.add_child(_spell_row("名字", name_edit))
	# 数据
	fields["hp"] = WorkbenchUI.spin_row(_spell_form_box, "血量", float(phase.hp), 1.0, 100000.0, 50.0)
	fields["time_limit"] = WorkbenchUI.spin_row(_spell_form_box, "时限", phase.time_limit, 1.0, 999.0, 1.0)
	fields["bonus"] = WorkbenchUI.spin_row(_spell_form_box, "奖励", float(phase.bonus), 0.0, 1000000.0, 1000.0)
	var timeout_cb := CheckButton.new()
	timeout_cb.text = "时符（无敌时限）"
	timeout_cb.button_pressed = phase.is_timeout_only
	fields["timeout"] = timeout_cb
	_spell_form_box.add_child(timeout_cb)
	# 移动/弹幕脚本
	var move_opt := _spell_script_opt(BossScriptRegistry.move_names(), phase.move_script)
	fields["move"] = move_opt
	_spell_form_box.add_child(_spell_row("移动", move_opt))
	var shoot_opt := _spell_script_opt(BossScriptRegistry.shoot_names(), phase.shoot_script)
	fields["shoot"] = shoot_opt
	_spell_form_box.add_child(_spell_row("弹幕", shoot_opt))
	# 脚本参数（移动+弹幕反射合并建议 + 已加参数行）
	_spell_form_box.add_child(WorkbenchUI.section_title("── 脚本参数 ──"))
	var suggest: Dictionary = {}
	var move_script: Script = BossScriptRegistry.move_script(move_opt.get_item_text(move_opt.selected)) \
		if move_opt.selected >= 0 else null
	var shoot_script: Script = BossScriptRegistry.shoot_script(shoot_opt.get_item_text(shoot_opt.selected)) \
		if shoot_opt.selected >= 0 else null
	var m_suggest := BossScriptRegistry.suggest_params(move_script)
	var s_suggest := BossScriptRegistry.suggest_params(shoot_script)
	for k in m_suggest:
		suggest[k] = m_suggest[k]
	for k in s_suggest:
		suggest[k] = s_suggest[k]
	if not suggest.is_empty():
		var sug_row := HBoxContainer.new()
		sug_row.add_theme_constant_override("separation", 4)
		for sk in suggest:
			var sb := Button.new()
			sb.text = str(sk)
			sb.add_theme_font_size_override("font_size", 12)
			sb.disabled = phase.params.has(str(sk))
			sb.pressed.connect(func():
				phase.params[str(sk)] = suggest[str(sk)]
				_refresh_spell_form()
			)
			sug_row.add_child(sb)
		_spell_form_box.add_child(sug_row)
	if phase.params.is_empty():
		var hint := Label.new()
		hint.text = "空（点上方参数添加）"
		hint.add_theme_font_size_override("font_size", 12)
		hint.modulate = Color(0.5, 0.5, 0.6)
		_spell_form_box.add_child(hint)
	else:
		for k in phase.params:
			_spell_form_box.add_child(_spell_param_row(phase, k, phase.params[k]))
	# 应用/保存
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 4)
	var apply := Button.new()
	apply.text = "应用"
	apply.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	apply.pressed.connect(func():
		_spell_apply(phase, fields)
		_log_line("✔ 符卡阶段已应用（重跑生效）")
	)
	btn_row.add_child(apply)
	var save := Button.new()
	save.text = "保存"
	save.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save.pressed.connect(func():
		_spell_apply(phase, fields)
		_save_spell()
	)
	btn_row.add_child(save)
	_spell_form_box.add_child(btn_row)


## 阶段表单行（label + control）
func _spell_row(label_text: String, control: Control) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	h.add_child(WorkbenchUI.param_label(label_text))
	h.add_child(control)
	return h


## 脚本下拉（带"无"；按当前脚本匹配选中）
func _spell_script_opt(names: Array, current_script: Script) -> OptionButton:
	var opt := OptionButton.new()
	opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opt.add_item("无")
	for n in names:
		opt.add_item(str(n))
		var s: Script = BossScriptRegistry.move_script(str(n))
		if s == null:
			s = BossScriptRegistry.shoot_script(str(n))
		if s == current_script:
			opt.selected = opt.item_count - 1
	return opt


## 应用表单 → PhaseData（脚本参数已在行内写回）
func _spell_apply(phase: PhaseData, fields: Dictionary) -> void:
	phase.name = fields["name"].text
	phase.hp = int(fields["hp"].value)
	phase.time_limit = fields["time_limit"].value
	phase.bonus = int(fields["bonus"].value)
	phase.is_timeout_only = fields["timeout"].button_pressed
	var move_name: String = fields["move"].get_item_text(fields["move"].selected)
	phase.move_script = BossScriptRegistry.move_script(move_name) if move_name != "无" else null
	var shoot_name: String = fields["shoot"].get_item_text(fields["shoot"].selected)
	phase.shoot_script = BossScriptRegistry.shoot_script(shoot_name) if shoot_name != "无" else null


## 保存符卡数据（BossData + 关卡，res:// 开发可写）
func _save_spell() -> void:
	if _stage_data == null or _stage_data.boss == null:
		return
	var err1 := ResourceSaver.save(_stage_data.boss, _stage_data.boss.resource_path)
	var err2 := ResourceSaver.save(_stage_data, _stage_data.resource_path)
	if err1 == OK and err2 == OK:
		_log_line("💾 符卡数据已保存")
	else:
		_log_line("⚠️ 符卡保存失败（boss=%d stage=%d）" % [err1, err2])


## x/y 轴小标签（坐标行用）
func _spell_axis_label(axis: String) -> Label:
	var l := Label.new()
	l.text = axis
	l.custom_minimum_size = Vector2(12, 0)
	l.add_theme_color_override("font_color", Color(0.45, 0.50, 0.60))
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


## 脚本参数行（值类型控件 + 行内写回 + 删除）
func _spell_param_row(phase: PhaseData, key: String, value: Variant) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.add_child(WorkbenchUI.param_key_label(key))
	var control: Control
	if value is bool:
		var cb := CheckButton.new()
		cb.button_pressed = value
		cb.toggled.connect(func(on: bool): phase.params[key] = on)
		control = cb
	elif typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
		var spin := SpinBox.new()
		spin.value = value
		spin.custom_minimum_size = Vector2(120, 0)
		var as_int := typeof(value) == TYPE_INT
		spin.value_changed.connect(func(v: float):
			if as_int:
				phase.params[key] = int(v)
			else:
				phase.params[key] = v
		)
		control = spin
	elif value is Vector2:
		control = null
		# Vector2 用两个小框（x/y 标签）
		row.add_child(_spell_axis_label("x"))
		var sx := WorkbenchUI.mini_spin(value.x, -10000, 10000)
		var sy := WorkbenchUI.mini_spin(value.y, -10000, 10000)
		row.add_child(sx)
		row.add_child(_spell_axis_label("y"))
		row.add_child(sy)
		sx.value_changed.connect(func(v: float): phase.params[key] = Vector2(v, phase.params[key].y))
		sy.value_changed.connect(func(v: float): phase.params[key] = Vector2(phase.params[key].x, v))
	else:
		var line := LineEdit.new()
		line.text = str(value)
		line.custom_minimum_size = Vector2(140, 0)
		line.text_submitted.connect(func(t: String): phase.params[key] = t)
		control = line
	if control != null:
		row.add_child(control)
	var del := Button.new()
	del.text = "×"
	del.add_theme_font_size_override("font_size", 11)
	del.custom_minimum_size = Vector2(22, 0)
	del.pressed.connect(func():
		phase.params.erase(key)
		_refresh_spell_form()
	)
	row.add_child(del)
	return row
