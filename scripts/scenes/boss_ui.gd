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
	if not phase or phase.time_limit <= 0 or _boss_ref.is_in_gap():
		_timer_label.visible = false
		return
	_timer_label.visible = true
	var rem := maxf(phase.time_limit - _boss_ref.get_elapsed(), 0.0)
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

const ANNOUNCE_FADE := 0.5
const ANNOUNCE_INITIAL_SCALE := 3.0
const ANNOUNCE_SHRINK := 0.6


func _play_spell_announce(spell_name: String) -> void:
	_clear_announce()
	_announce_label = _make_announce_label(spell_name)
	$Control.add_child(_announce_label)
	
	var size: Vector2 = $Control.size
	var center: Vector2 = size * 0.5
	var label_size := _announce_label.get_minimum_size()
	
	_announce_label.scale = Vector2(ANNOUNCE_INITIAL_SCALE, ANNOUNCE_INITIAL_SCALE)
	_announce_label.position = center - label_size * ANNOUNCE_INITIAL_SCALE / 2.0
	
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_announce_label, "modulate:a", 1.0, ANNOUNCE_FADE)
	tw.tween_property(_announce_label, "scale", Vector2(ANNOUNCE_SHRINK, ANNOUNCE_SHRINK), ANNOUNCE_FADE).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(_announce_label, "position", center - label_size * ANNOUNCE_SHRINK / 2.0, ANNOUNCE_FADE).set_trans(Tween.TRANS_QUAD)
	tw.set_parallel(false)
	tw.tween_interval(0.2)
	tw.tween_property(_announce_label, "position", size - label_size * ANNOUNCE_SHRINK, 1.0).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(_announce_label, "position", Vector2(size.x - (label_size * ANNOUNCE_SHRINK).x, 0), 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(_add_info_labels)


func _make_announce_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 48)
	label.modulate.a = 0.0
	return label


func _add_info_labels() -> void:
	if not _announce_label:
		return
	var parent := _announce_label
	var label_h := parent.get_minimum_size().y
	
	_bonus_label = _make_sub_label(HORIZONTAL_ALIGNMENT_LEFT, Color(1, 0.9, 0.3))
	_bonus_label.position = Vector2(0, label_h)
	parent.add_child(_bonus_label)
	
	_capture_label = _make_sub_label(HORIZONTAL_ALIGNMENT_RIGHT, Color(0.5, 0.8, 0.5))
	_capture_label.position = Vector2(parent.get_minimum_size().x * 0.6, label_h)
	parent.add_child(_capture_label)
	_update_capture_text()


func _make_sub_label(align: HorizontalAlignment, color: Color) -> Label:
	var label := Label.new()
	label.horizontal_alignment = align
	label.add_theme_font_size_override("font_size", 32)
	label.add_theme_color_override("font_color", color)
	return label

func _update_capture_text() -> void:
	if not _capture_label or not _boss_ref: return
	var pid := _boss_ref.get_phase_id()
	if not pid: return
	var book: SpellRecordBook = GameState.spell_book
	var rec: SpellRecord = book.get_record(pid.stage_id, pid.phase_index, pid.character, pid.difficulty)
	if rec:
		if GameState.is_practice_mode:
			_capture_label.text = "%02d/%02d" % [rec.practice_captures, rec.practice_attempts]
		else:
			_capture_label.text = "%02d/%02d" % [rec.captures, rec.attempts]
