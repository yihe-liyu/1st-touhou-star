# GameState.gd
extends Node

var player: Player = null
var active_enemies: Array = []
var current_score: int = 0
var high_scores: Dictionary = {}
var graze_count: int = 0  # 擦弹数
## 0=Easy 1=Normal 2=Hard 3=Lunatic
var selected_difficulty: int = 1
## 0=Reimu 1=Marisa
var selected_character: int = 0
## 火力值内部表示：0 = 1.00, 300 = 4.00，每 1 单位 = 0.01
var power_raw: int = 300
var _config: ConfigFile
const SAVE_PATH: String = "user://save_data.cfg"

func _ready():
	load_save_data()
	if not GameEvents.enemy_killed.is_connected(_on_enemy_killed):
		GameEvents.enemy_killed.connect(_on_enemy_killed)

func load_save_data():
	_config = ConfigFile.new()
	if _config.load(SAVE_PATH) != OK:
		return
	for key in _config.get_section_keys("high_scores"):
		high_scores[int(key)] = _config.get_value("high_scores", key)

func save_high_score(stage_id: int, score: int):
	var prev = get_high_score(stage_id)
	if score <= prev:
		return
	high_scores[stage_id] = score
	_config.set_value("high_scores", str(stage_id), score)
	_config.save(SAVE_PATH)

func get_high_score(stage_id: int) -> int:
	return high_scores.get(stage_id, 0)

func add_score(amount: int):
	current_score += amount

func reset_score():
	current_score = 0
	graze_count = 0

func _on_enemy_killed(score: int, _position: Vector2):
	add_score(score)

func get_power_display() -> String:
	var value := 1.00 + power_raw * 0.01
	return "%.2f" % value

func get_power_float() -> float:
	return 1.00 + power_raw * 0.01

func add_power(amount: int) -> void:
	power_raw = clampi(power_raw + amount, 0, 300)

func on_miss_power_penalty() -> void:
	power_raw = clampi(power_raw - 50, 0, 300)

func get_active_enemies() -> Array:
	return active_enemies

func clear_enemies():
	for enemy in active_enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	active_enemies.clear()
