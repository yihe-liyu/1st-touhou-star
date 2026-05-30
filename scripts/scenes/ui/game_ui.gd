extends CanvasLayer
class_name GameUI
## 游戏内 HUD —— 更新分数、擦弹、火力等数值

var _score_label: Label
var _hi_score_label: Label
var _graze_label: Label
var _power_label: Label


func _ready() -> void:
	# 动态创建数字标签
	_create_number_label("HiScoreLabel", $HighScore.position + Vector2(0, 24))
	_create_number_label("ScoreLabel", $Score.position + Vector2(0, 24))
	_create_number_label("GrazeLabel", $Graze.position + Vector2(0, 24))
	_create_number_label("PowerLabel", $Power.position + Vector2(0, 24))
	
	# 重新获取引用
	_score_label = $ScoreLabel
	_hi_score_label = $HiScoreLabel
	_graze_label = $GrazeLabel
	_power_label = $PowerLabel


func _process(_delta: float) -> void:
	if not is_instance_valid(GameState):
		return
	
	_hi_score_label.text = "%08d" % GameState.get_high_score(0)
	_score_label.text = "%08d" % GameState.current_score
	_graze_label.text = "%d" % GameState.graze_count
	
	if GameState.player and is_instance_valid(GameState.player):
		_power_label.text = GameState.player.get_power_display()


func _create_number_label(node_name: String, pos: Vector2) -> void:
	var lbl := Label.new()
	lbl.name = node_name
	lbl.offset_left = pos.x
	lbl.offset_top = pos.y
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	add_child(lbl)
