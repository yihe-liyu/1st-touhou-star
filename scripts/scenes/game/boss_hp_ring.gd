# BossHPRing.gd
extends Node2D
## Boss 环形血条，跟随 Boss 位置

@export var radius: float = 32.0
@export var thickness: float = 4.0
@export var ring_color_spell: Color = Color(0.2, 0.8, 1.0, 0.9)
@export var ring_color_non: Color = Color(0.0, 0.6, 0.0, 0.8)
@export var bg_color: Color = Color(0.3, 0.3, 0.3, 0.4)

var _boss: Boss
var _max_hp: int = 1
var _hp: int = 1
var _is_spell: bool = false

func setup(p_boss: Boss) -> void:
	_boss = p_boss
	position = Vector2.ZERO
	GameEvents.phase_start.connect(_on_phase_start)
	GameEvents.phase_end.connect(_on_phase_end)
	queue_redraw()

func _on_phase_start(phase: PhaseData) -> void:
	_is_spell = phase.uid != 0
	_max_hp = phase.hp
	_hp = phase.hp
	queue_redraw()

func _on_phase_end(_captured: bool, _bonus: int) -> void:
	queue_redraw()

func _process(_delta: float) -> void:
	if not _boss or not is_instance_valid(_boss):
		return
	var ph := _boss.current_phase()
	if not ph or ph.hp <= 0:
		return
	var ch := _boss.hp
	if ch != _hp or ph.hp != _max_hp:
		_hp = ch
		_max_hp = ph.hp
		queue_redraw()

func _draw() -> void:
	if _max_hp <= 0: return
	var ratio := clampf(float(_hp) / float(_max_hp), 0.0, 1.0)
	var angle_from := -PI / 2.0
	var angle_to := angle_from + TAU * ratio
	
	# 背景环
	draw_arc(Vector2.ZERO, radius, 0, TAU, 64, bg_color, thickness)
	# 血量弧
	var col := ring_color_spell if _is_spell else ring_color_non
	draw_arc(Vector2.ZERO, radius, angle_from, angle_to, 64, col, thickness)
