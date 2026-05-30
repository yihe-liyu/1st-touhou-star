extends CanvasLayer
class_name GameUI

const NumberSpriteClass = preload("res://scripts/ui/number_sprite.gd")

var _score_num: Node2D
var _hi_score_num: Node2D
var _graze_num: Node2D
var _power_label: Label


func _ready() -> void:
	# 创建数字精灵（用贴图显示，替换为你的数字贴图）
	_score_num = _make_number_sprite("ScoreNumber", $Score.position + Vector2(0, 24))
	_hi_score_num = _make_number_sprite("HiScoreNumber", $HighScore.position + Vector2(0, 24))
	_graze_num = _make_number_sprite("GrazeNumber", $Graze.position + Vector2(0, 24))
	
	# Power 带小数点，用 Label
	_power_label = Label.new()
	_power_label.offset_left = $Power.position.x
	_power_label.offset_top = $Power.position.y + 24
	_power_label.z_index = 128
	_power_label.add_theme_font_size_override("font_size", 18)
	_power_label.add_theme_color_override("font_color", Color.WHITE)
	add_child(_power_label)


func _make_number_sprite(node_name: String, pos: Vector2) -> Node2D:
	var ns := NumberSpriteClass.new()
	ns.name = node_name
	ns.position = pos
	ns.z_index = 128
	ns.digit_count = 8
	add_child(ns)
	return ns


func _process(_delta: float) -> void:
	if not is_instance_valid(GameState):
		return
	
	_hi_score_num.value = GameState.get_high_score(0)
	_score_num.value = GameState.current_score
	_graze_num.value = GameState.graze_count
	
	if GameState.player and is_instance_valid(GameState.player):
		_power_label.text = GameState.get_power_display()
