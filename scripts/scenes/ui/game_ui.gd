extends CanvasLayer
class_name GameUI

@onready var _score_num: NumberSprite = $ScoreNumber
@onready var _hi_score_num: NumberSprite = $HiScoreNumber
@onready var _graze_num: NumberSprite = $GrazeNumber
@onready var _power_label: Label = $PowerLabel


func _ready() -> void:
	# Power 用 Label 因为带小数点
	_power_label = Label.new()
	_power_label.name = "PowerLabel"
	_power_label.offset_left = $Power.position.x
	_power_label.offset_top = $Power.position.y + 24
	_power_label.z_index = 128
	_power_label.add_theme_font_size_override("font_size", 18)
	_power_label.add_theme_color_override("font_color", Color.WHITE)
	add_child(_power_label)


func _process(_delta: float) -> void:
	if not is_instance_valid(GameState):
		return
	
	_hi_score_num.value = GameState.get_high_score(0)
	_score_num.value = GameState.current_score
	_graze_num.value = GameState.graze_count
	
	if GameState.player and is_instance_valid(GameState.player):
		_power_label.text = GameState.get_power_display()
