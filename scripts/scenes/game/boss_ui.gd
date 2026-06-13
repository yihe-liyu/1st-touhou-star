# BossUI.gd
extends CanvasLayer

@onready var _name_label: Label = $Control/BossName
@onready var _spell_label: Label = $Control/SpellName
@onready var _bonus_label: Label = $Control/Bonus
@onready var _hp_fill: ColorRect = $Control/HPBar/Fill
@onready var _hp_bg: ColorRect = $Control/HPBar
@onready var _history: HBoxContainer = $Control/History

var _history_colors: Array[Color] = []

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
	_hp_fill.size.x = _hp_bg.size.x
	visible = true

func _on_boss_defeated(_boss: Node) -> void:
	visible = false

func _on_phase_start(phase: PhaseData) -> void:
	if phase.name != "":
		_spell_label.text = phase.name
		_spell_label.visible = true
	_bonus_label.text = str(phase.bonus)
	_hp_fill.size.x = _hp_bg.size.x

func _on_tick(bonus: int) -> void:
	_bonus_label.text = str(bonus)

func _on_phase_end(captured: bool, _bonus: int) -> void:
	_spell_label.visible = false
	if _history_colors.size() >= 8:
		_history_colors.pop_front()
	_history_colors.append(Color.GREEN if captured else Color.RED)
	_refresh_history()

func _refresh_history() -> void:
	for child in _history.get_children():
		child.queue_free()
	for c in _history_colors:
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(12, 12)
		dot.color = c
		_history.add_child(dot)
