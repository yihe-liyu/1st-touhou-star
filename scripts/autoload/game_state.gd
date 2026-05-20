# GameState.gd
extends Node

var player: Player = null
var active_enemies: Array = []
var current_score: int = 0
var high_scores: Dictionary = {}
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

func _on_enemy_killed(score: int, _position: Vector2):
	add_score(score)

func get_active_enemies() -> Array:
	return active_enemies

func clear_enemies():
	for enemy in active_enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	active_enemies.clear()
