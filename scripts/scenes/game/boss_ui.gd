# BossUI.gd
extends CanvasLayer

const GRAY := Color(0.4, 0.4, 0.4, 1.0)
const GREEN := Color(0.098, 0.7, 0.198, 1.0)
const GOLD := Color(0.95, 0.839, 0.475, 1.0)
const RED := Color(1.0, 0.0, 0.0, 1.0)
const PURPLE := Color(0.858, 0.5, 1.0, 1.0)
const DOT_SIZE := 16.0

@onready var _name_label: Label = $Control/BossName
@onready var _spell_label: Label = $Control/SpellName
@onready var _bonus_label: Label = $Control/Bonus
@onready var _history: HBoxContainer = $Control/History

var _dots: Array[ColorRect] = []  # [0]=最后阶段(左), [n-1]=第一阶段(右)
var _phase_idx: int = 0           # 战斗顺序: 0=第一阶段, 1=第二阶段...
var _announce_label: Label

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
	
	for d in _dots: d.queue_free()
	_dots.clear()
	_phase_idx = 0
	
	for i in range(bd.phases.size() - 1, -1, -1):
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
		_play_spell_announce(phase.name)
		_bonus_label.text = str(phase.bonus)
		_bonus_label.visible = true
	else:
		_spell_label.visible = false
		_bonus_label.visible = false
	
	var vis_idx := _dots.size() - 1 - _phase_idx
	if vis_idx >= 0 and vis_idx < _dots.size():
		_dots[vis_idx].color = PURPLE

func _on_tick(bonus: int) -> void:
	if _bonus_label.visible:
		_bonus_label.text = str(bonus)

func _on_phase_end(captured: bool, _bonus: int) -> void:
	_spell_label.visible = false
	_bonus_label.visible = false
	if _announce_label and is_instance_valid(_announce_label):
		_announce_label.queue_free()
		_announce_label = null
	var vis_idx := _dots.size() - 1 - _phase_idx
	if vis_idx >= 0 and vis_idx < _dots.size():
		_dots[vis_idx].color = GOLD if captured else RED
	_phase_idx += 1

# 符卡名入场动画
func _play_spell_announce(spell_name: String) -> void:
	if _announce_label and is_instance_valid(_announce_label):
		_announce_label.queue_free()
	
	var lbl := Label.new()
	_announce_label = lbl
	lbl.text = spell_name
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 48)
	lbl.modulate.a = 0.0
	$Control.add_child(lbl)
	
	var vs: Vector2 = $Control.size
	var center := Vector2(vs.x * 0.5, vs.y * 0.5)
	var below := Vector2(vs.x, vs.y)
	var top_right := Vector2(vs.x - 80.0, 50.0)
	
	# 1. 屏幕中央大字(scale=3)淡入
	lbl.scale = Vector2(3.0, 3.0)
	var label_size: Vector2 = lbl.get_minimum_size() * lbl.scale
	lbl.position = center - label_size / 2.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "modulate:a", 1.0, 0.5)
	
	# 2. 缩小+下移(scale→1)
	tw.tween_property(lbl, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_CUBIC)
	tw.set_parallel(false)
	#tw.tween_property(lbl, "position", vs - Vector2(128, 64), 0.5)
	
	# 3. 加速/减速飞向右上
	#tw.tween_property(lbl, "position", top_right, 0.7)\
		#.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	#
	## 4. 平滑缩为小字(scale→0.4)停住
	#tw.tween_property(lbl, "scale", Vector2(0.4, 0.4), 0.3)
