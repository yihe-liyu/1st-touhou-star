class_name SaveManager
extends RefCounted
## 高分存档管理（从 GameState 拆出，职责单一）

const SAVE_PATH: String = "user://save_data.cfg"

var high_scores: Dictionary = {}
var _config: ConfigFile


func load() -> void:
	_config = ConfigFile.new()
	if _config.load(SAVE_PATH) != OK:
		return
	for key in _config.get_section_keys("high_scores"):
		high_scores[int(key)] = _config.get_value("high_scores", key)


func save_high_score(stage_id: int, score: int):
	var prev: int = get_high_score(stage_id)
	if score <= prev:
		return
	high_scores[stage_id] = score
	_config.set_value("high_scores", str(stage_id), score)
	_config.save(SAVE_PATH)


func get_high_score(stage_id: int) -> int:
	return high_scores.get(stage_id, 0)
