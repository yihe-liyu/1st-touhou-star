extends CanvasLayer
class_name GameUI

const NumberSpriteClass = preload("res://scripts/ui/number_sprite.gd")

var _score_num: Node2D
var _hi_score_num: Node2D
var _graze_num: Node2D
var _power_num: Node2D
var _power_label: Label


func _ready() -> void:
	var tex := preload("res://assets/Textures/ascii/ascii.png")
	_score_num = _make_number_sprite("ScoreNumber", $Score.position + Vector2(150, 0), tex)
	_hi_score_num = _make_number_sprite("HiScoreNumber", $HighScore.position + Vector2(150, 0), tex)
	_graze_num = _make_number_sprite("GrazeNumber", $Graze.position + Vector2(150, 0), tex)
	_power_num = _make_number_sprite("PowerNumber", $Power.position + Vector2(150, 0), tex, 10)


func _make_number_sprite(node_name: String, pos: Vector2, tex: Texture2D = null, dcount: int = 8) -> Node2D:
	var ns := NumberSpriteClass.new()
	ns.name = node_name
	ns.position = pos
	ns.z_index = 128
	ns.digit_count = dcount
	ns.digit_texture = tex
	ns.dot_index = 10
	ns.slash_index = 11
	ns.char_count = 12  # 0-9 . /
	add_child(ns)
	return ns


func _process(_delta: float) -> void:
	if not is_instance_valid(GameState):
		return
	
	_hi_score_num.value = GameState.get_high_score(0)
	_score_num.value = GameState.current_score
	_graze_num.value = GameState.graze_count
	
	if GameState.player and is_instance_valid(GameState.player):
		_power_num.show_text(GameState.get_power_display() + "/4.00")
