extends Node2D
## Boss 环形血条，跟随 Boss 位置

@export var radius: float = 128.0
@export var thickness: float = 5.0
@export var fill_color: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var edge_color: Color = Color(1.0, 0.0, 0.0, 1.0)

var _boss: Boss
var _max_hp: int = 1
var _hp: int = 1

func setup(p_boss: Boss) -> void:
	_boss = p_boss
	position = Vector2.ZERO
	z_index = 10
	GameEvents.phase_start.connect(_on_phase_start)
	queue_redraw()

func _on_phase_start(phase: PhaseData) -> void:
	_max_hp = phase.hp
	_hp = phase.hp
	queue_redraw()

func _process(_delta: float) -> void:
	if not _boss or not is_instance_valid(_boss):
		queue_redraw(); return
	
	var ph := _boss.current_phase()
	if not ph or _boss.is_in_gap():
		visible = false; return  # 还没开战 或 阶段间隙
	visible = true
	
	if ph.hp <= 0:
		return
	var ch := _boss.hp
	if ch != _hp or ph.hp != _max_hp:
		_hp = ch
		_max_hp = ph.hp
		queue_redraw()

func _draw() -> void:
	if _max_hp <= 0: return
	
	var ratio := clampf(float(_hp) / float(_max_hp), 0.0, 1.0)
	var start_angle := -PI / 2.0
	var end_angle := start_angle - TAU * ratio
	
	
	# 红色空心环 = 内外两圈细线
	var ring_half := thickness * 0.5 + 1.0
	draw_arc(Vector2.ZERO, radius + ring_half, 0, TAU, 64, edge_color, 2.0, true)
	draw_arc(Vector2.ZERO, radius - ring_half, 0, TAU, 64, edge_color, 2.0, true)

	# 白色 HP 填充
	draw_arc(Vector2.ZERO, radius, start_angle, end_angle, 64, fill_color, thickness)
