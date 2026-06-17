# BossUI.gd
extends CanvasLayer

const GRAY := Color(0.4, 0.4, 0.4, 1.0)
const GREEN := Color(0.098, 0.7, 0.198, 1.0)
const GOLD := Color(0.95, 0.839, 0.475, 1.0)
const RED := Color(1.0, 0.0, 0.0, 1.0)
const PURPLE := Color(0.858, 0.5, 1.0, 1.0)
const DOT_SIZE := 16.0

@onready var _name_label: Label = $Control/BossName
@onready var _history: HBoxContainer = $Control/History

var _dots: Array[ColorRect] = []
var _phase_idx: int = 0
var _announce_label: Label
var _bonus_label: Label
var _capture_label: Label
var _boss_ref: Boss
var _timer_label: Label

func _ready() -> void:
	visible = false
	GameEvents.boss_spawned.connect(_on_boss_spawned)
	GameEvents.boss_defeated.connect(_on_boss_defeated)
	GameEvents.phase_start.connect(_on_phase_start)
	GameEvents.phase_end.connect(_on_phase_end)
	GameEvents.phase_bonus_tick.connect(_on_tick)

func _on_boss_spawned(boss: Node) -> void:
	_boss_ref = boss as Boss
	var boss_data: BossData = boss.boss_data
	_name_label.text = boss_data.boss_name if boss_data.boss_name != "" else "???"
	
	if not _timer_label:
		_timer_label = Label.new()
		_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_timer_label.add_theme_font_size_override("font_size", 32)
		$Control.add_child(_timer_label)
	_timer_label.position = Vector2($Control.size.x / 2.0 - 16, 16)
	_timer_label.visible = false
	
	for d in _dots: d.queue_free()
	_dots.clear()
	_phase_idx = 0
	
	for i in range(boss_data.phases.size() - 1, -1, -1):
		var phase := boss_data.phases[i]
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(DOT_SIZE, DOT_SIZE)
		dot.color = GRAY if phase.uid == 0 else GREEN
		_history.add_child(dot)
		_dots.append(dot)
	
	visible = true

func _process(_delta: float) -> void:
	if not _boss_ref or not is_instance_valid(_boss_ref) or not visible:
		return
	var phase := _boss_ref.current_phase()
	# 间隙期（换阶段之间）不显示
	if not phase or phase.time_limit <= 0 or _boss_ref._in_gap:
		_timer_label.visible = false
		return
	_timer_label.visible = true
	var rem := maxf(phase.time_limit - _boss_ref._elapsed, 0.0)
	_timer_label.text = "%02d" % int(ceil(rem))

func _on_boss_defeated(_boss: Node) -> void:
	visible = false

func _on_phase_start(phase: PhaseData) -> void:
	if phase.uid != 0:
		_play_spell_announce(phase.name)
	else:
		_clear_announce()
	
	var vis_idx := _dots.size() - 1 - _phase_idx
	if vis_idx >= 0 and vis_idx < _dots.size():
		_dots[vis_idx].color = PURPLE

func _on_tick(bonus: int) -> void:
	if _bonus_label and is_instance_valid(_bonus_label):
		_bonus_label.text = str(bonus)

func _on_phase_end(captured: bool, _bonus: int) -> void:
	_clear_announce()
	var vis_idx := _dots.size() - 1 - _phase_idx
	if vis_idx >= 0 and vis_idx < _dots.size():
		_dots[vis_idx].color = GOLD if captured else RED
	_phase_idx += 1

func _clear_announce() -> void:
	if _announce_label and is_instance_valid(_announce_label):
		_announce_label.queue_free()
		_announce_label = null
	_bonus_label = null
	_capture_label = null

# ═══ 符卡名入场动画 ═══

func _play_spell_announce(spell_name: String) -> void:
	_clear_announce()
	
	var label := Label.new()
	_announce_label = label
	label.text = spell_name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 48)
	label.modulate.a = 0.0
	$Control.add_child(label)
	
	var size: Vector2 = $Control.size
	var center := Vector2(size.x * 0.5, size.y * 0.5)
	var label_size: Vector2 = label.get_minimum_size()
	
	# 1. 屏幕中央大字(scale=3)淡入+缩小
	label.scale = Vector2(3.0, 3.0)
	label.position = center - label_size * 3.0 / 2.0
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "modulate:a", 1.0, 0.5)
	tween.tween_property(label, "scale", Vector2(0.6, 0.6), 0.5).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(label, "position", center - label_size * 0.6 / 2.0, 0.5).set_trans(Tween.TRANS_QUAD)
	tween.set_parallel(false)
	
	tween.tween_interval(0.2)
	
	# 2. 下移(scale→1)
	tween.tween_property(label, "position", size - label_size * 0.6, 1.0).set_trans(Tween.TRANS_QUAD)
	
	# 3. 加速/减速飞向右上
	var top_right := Vector2(size.x - (label_size * 0.6).x, 0)
	tween.tween_property(label, "position", top_right, 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	
	# 4. Bonus(左下) / 收取率(右下)
	tween.tween_callback(_add_info_labels)

func _add_info_labels() -> void:
	if not _announce_label: return
	var parent := _announce_label
	var label_h := parent.get_minimum_size().y
	
	# Bonus — 左下
	_bonus_label = Label.new()
	_bonus_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_bonus_label.add_theme_font_size_override("font_size", 32)
	_bonus_label.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
	parent.add_child(_bonus_label)
	_bonus_label.position = Vector2(0, label_h)
	
	# 收取率 — 右下 (仅 Story)
	if not GameState.is_practice_mode:
		_capture_label = Label.new()
		_capture_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_capture_label.add_theme_font_size_override("font_size", 32)
		_capture_label.add_theme_color_override("font_color", Color(0.5, 0.8, 0.5))
		parent.add_child(_capture_label)
		_capture_label.position = Vector2(parent.get_minimum_size().x * 0.6, label_h)
		_update_capture_text()

func _update_capture_text() -> void:
	if not _capture_label or not _boss_ref: return
	var book: SpellRecordBook = GameState.spell_book
	var rec: SpellRecord = book.get_record(
		GameState.selected_character,
		GameState.practice_stage_id,
		SpellRecord.PhaseType.SPELL,
		1,  # TODO: 多符卡阶段号
		GameState.selected_difficulty
	)
	if rec:
		_capture_label.text = "%02d/%02d" % [rec.captures, rec.attempts]
