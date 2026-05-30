extends CanvasLayer
class_name GameUI
## 游戏 HUD —— Score / HiScore / Power / MaxPoint / Graze

const NumberSpriteClass = preload("res://scripts/ui/number_sprite.gd")

var _hi_score_num: Node2D
var _score_num: Node2D
var _power_num: Node2D
var _max_point_num: Node2D
var _graze_num: Node2D
var _memory_num: Node2D
var _memory_rect: ColorRect


func _ready() -> void:
	var tex := preload("res://assets/Textures/ascii/ascii.png")
	_hi_score_num = _make_number_sprite("HiScoreNumber",  $HighScore.position + Vector2(102, 0), tex, 10)
	_score_num    = _make_number_sprite("ScoreNumber",    $Score.position     + Vector2(102, 0), tex, 10)
	_power_num    = _make_number_sprite("PowerNumber",    $Power.position     + Vector2(78, 0), tex, 10)
	_max_point_num= _make_number_sprite("MaxPointNumber", $Point.position     + Vector2(102, 0), tex)
	_graze_num    = _make_number_sprite("GrazeNumber",    $Graze.position     + Vector2(102, 0), tex)
	
	_memory_rect = $Memory/OutlineRect
	_memory_num = _make_number_sprite_on("MemoryNumber", $Memory, $MemoryValue.position + Vector2(78, 0), tex, 6)

	# 颜色
	_hi_score_num.modulate  = Color(0.735, 0.735, 0.735)
	_power_num.modulate     = Color(1.0, 0.4, 0.0)
	_max_point_num.modulate = Color(0.165, 0.831, 1.0)
	_graze_num.modulate     = Color(0.735, 0.735, 0.735)
	_memory_num.modulate    = Color(0.592, 0.549, 1.0, 1.0)

	# 对齐：不带前导零的用左对齐
	_max_point_num.left_align = true
	_graze_num.left_align     = true
	_memory_num.pct_index     = 13
	_memory_num.minus_index   = 12
	_memory_num.char_count    = 14
	_memory_num.z_index       = 128


func _make_number_sprite_on(p_name: String, parent: Node, pos: Vector2, tex: Texture2D = null, dcount: int = 8) -> Node2D:
	var ns := _make_number_sprite(p_name, pos, tex, dcount)
	remove_child(ns)
	parent.add_child(ns)
	ns.z_index = 0  # 同层内靠到最上
	return ns


func _make_number_sprite(p_name: String, pos: Vector2, tex: Texture2D = null, dcount: int = 8) -> Node2D:
	var ns := NumberSpriteClass.new()
	ns.name = p_name
	ns.position = pos
	ns.z_index = 128
	ns.digit_count = dcount
	ns.digit_texture = tex
	ns.char_count = 14   # 贴图: 0-9 . / - %
	ns.dot_index = 10    # 10='.'
	ns.slash_index = 11  # 11='/'
	ns.minus_index = -1  # 普通不用 '-'
	ns.pct_index = -1    # 普通不用 '%'
	add_child(ns)
	return ns


func _process(_delta: float) -> void:
	if not is_instance_valid(GameState):
		return

	_hi_score_num.value = GameState.get_high_score(0)
	_score_num.value    = GameState.current_score
	_max_point_num.value= GameState.max_point
	_graze_num.value    = GameState.graze_count
	_memory_num.show_text("%d%%" % int(GameState.memory_value))

	if GameState.player and is_instance_valid(GameState.player):
		_power_num.show_text(GameState.get_power_display() + "/4.00")
	
	# 同步 memory → shader saturation
	if _memory_rect and _memory_rect.material is ShaderMaterial:
		_memory_rect.material.set_shader_parameter("memory", float(GameState.memory_value))
