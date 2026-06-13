# BossUI.gd
extends CanvasLayer

const GRAY := Color(0.4, 0.4, 0.4, 0.8)
const GREEN := Color(0.1, 0.7, 0.2, 0.8)
const GOLD := Color(0.95, 0.75, 0.1, 0.9)
const RED := Color(0.9, 0.1, 0.1, 0.9)
const PURPLE := Color(0.7, 0.2, 0.9, 0.9)
const DOT_SIZE := 16.0
const DOT_GAP := 4.0

@onready var _name_label: Label = $Control/BossName
@onready var _spell_label: Label = $Control/SpellName
@onready var _bonus_label: Label = $Control/Bonus
@onready var _history: HBoxContainer = $Control/History

var _dots: Array[ColorRect] = []
var _current_idx: int = -1

func _ready() -> void:
	visible = false
	_spell_label.visible = false
	GameEvents.boss_spawned.connect(_on_boss_spawned)
	GameEvents.boss_defeated.connect(_on_boss_defeated)
	GameEvents.phase_start.connect(_on_phase_start)
	GameEvents.phase_end.connect(_on_phase_end)
	GameEvents.phase_bonus_tick.connect(_on_tick)

func _on_boss_spawned(boss: Node) -> void:
	var bd: BossData = boss.boss_data
	_name_label.text = bd.boss_name if bd.boss_name != "" else "???"
	_spell_label.visible = false
	
	# 清旧 → 建全部阶段指示块
	for d in _dots:
		d.queue_free()
	_dots.clear()
	_current_idx = -1
	_history.alignment = BoxContainer.ALIGNMENT_END
	
	for i in range(bd.phases.size()):  # 左=先出, 右=后出; HBox 右对齐
		var ph := bd.phases[i]
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(DOT_SIZE, DOT_SIZE)
		dot.color = GRAY if ph.uid == 0 else GREEN
		_history.add_child(dot)
		_dots.append(dot)
	
	visible = true

func _on_boss_defeated(_boss: Node) -> void:
	visible = false

func _on_phase_start(phase: PhaseData) -> void:
	if phase.uid != 0:
		_spell_label.text = phase.name
		_spell_label.visible = true
	else:
		_spell_label.visible = false
	_bonus_label.text = str(phase.bonus)
	
	# 前一个 → 前一个状态已在 _on_phase_end 设置
	# 当前 → 紫色
	_current_idx += 1
	if _current_idx < _dots.size():
		_dots[_current_idx].color = PURPLE

func _on_tick(bonus: int) -> void:
	_bonus_label.text = str(bonus)

func _on_phase_end(captured: bool, _bonus: int) -> void:
	_spell_label.visible = false
	if _current_idx >= 0 and _current_idx < _dots.size():
		_dots[_current_idx].color = GOLD if captured else RED
