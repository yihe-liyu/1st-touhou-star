# SpellRecordBook.gd
extends Resource
class_name SpellRecordBook

const SpellRecordClass = preload("res://scripts/data/spell_record.gd")

## 全符卡记录，主键 (stage_id, phase_index, character, difficulty)
@export var records: Array[SpellRecord] = []


## 以 (stage, phase_index, character, difficulty) 查重
func get_record(stage: int, phase_index: int, character: int, difficulty: int) -> SpellRecord:
	for r in records:
		if r.stage == stage and r.phase_index == phase_index and r.character == character and r.difficulty == difficulty:
			return r
	return null


func get_or_create(stage: int, phase_index: int, character: int, difficulty: int,
		uid: int = 0, phase_type: int = 0, phase_number: int = 1,
		pname: String = "") -> SpellRecord:
	var r := get_record(stage, phase_index, character, difficulty)
	if r: return r
	r = SpellRecordClass.new()
	r.stage = stage
	r.phase_index = phase_index
	r.character = character
	r.difficulty = difficulty
	if uid > 0: r.uid = uid
	r.phase_type = phase_type
	r.phase_number = phase_number
	if pname != "": r.name = pname
	records.append(r)
	return r


func record_attempt(stage: int, phase_index: int, character: int, difficulty: int,
		captured: bool, score: int, elapsed: float, extra: Dictionary = {}) -> void:
	var r := get_or_create(stage, phase_index, character, difficulty,
		extra.get("uid", 0), extra.get("phase_type", 0),
		extra.get("phase_number", 1), extra.get("name", ""))
	r.attempts += 1
	if captured:
		r.captures += 1
		if score > r.best_score:
			r.best_score = score
		if elapsed > 0:
			if r.best_time == 0 or elapsed < r.best_time:
				r.best_time = elapsed


func record_practice(stage: int, phase_index: int, character: int, difficulty: int,
		captured: bool) -> void:
	var r := get_record(stage, phase_index, character, difficulty)
	if not r:
		return  # 练习只更新已有记录，首次记录由普通模式生成
	r.practice_attempts += 1
	if captured:
		r.practice_captures += 1



