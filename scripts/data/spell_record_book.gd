# SpellRecordBook.gd
extends Resource
class_name SpellRecordBook

const SpellRecordClass = preload("res://scripts/data/spell_record.gd")

## 全符卡收取记录
@export var records: Array[SpellRecord] = []

func get_record(character: int, stage_id: int, phase_type: int, phase_num: int, difficulty: int) -> SpellRecord:
	for r in records:
		if r.character == character and r.stage == stage_id \
		   and r.phase_type == phase_type and r.phase_number == phase_num \
		   and r.difficulty == difficulty:
			return r
	return null

func record_attempt(character: int, stage_id: int, phase_type: int, phase_num: int, difficulty: int, captured: bool, score: int, elapsed: float, order: int = 0, uid: int = 0, sname: String = "") -> void:
	var r := get_or_create(character, stage_id, phase_type, phase_num, difficulty, order, uid, sname)
	if not r: return
	r.attempts += 1
	if captured:
		r.captures += 1
		if score > r.best_score:
			r.best_score = score
		if elapsed > 0:
			if r.best_time == 0 or elapsed < r.best_time:
				r.best_time = elapsed

func record_practice(character: int, stage_id: int, phase_type: int, phase_num: int, difficulty: int, captured: bool, order: int = 0) -> void:
	var r := get_or_create(character, stage_id, phase_type, phase_num, difficulty, order)
	if not r: return
	r.practice_attempts += 1
	if captured:
		r.practice_captures += 1

func get_or_create(character: int, stage_id: int, phase_type: int, phase_num: int, difficulty: int, order: int = 0, uid: int = 0, sname: String = "") -> SpellRecord:
	var r := get_record(character, stage_id, phase_type, phase_num, difficulty)
	if r: return r
	r = SpellRecordClass.new()
	r.character = character
	r.stage = stage_id
	r.phase_type = phase_type
	r.phase_number = phase_num
	r.difficulty = difficulty
	if order > 0:
		r.phase_order = order
	if uid > 0:
		r.spell_uid = uid
	if sname != "":
		r.spell_name = sname
	records.append(r)
	return r

func get_by_stage(character: int, stage_id: int) -> Array[SpellRecord]:
	var result: Array[SpellRecord] = []
	for r in records:
		if r.character == character and r.stage == stage_id:
			result.append(r)
	return result

func get_history(character: int, stage_id: int, phase_type: int, phase_num: int, difficulty: int) -> String:
	var r := get_record(character, stage_id, phase_type, phase_num, difficulty)
	if not r: return "0/0"
	return "%d/%d" % [r.captures, r.attempts]
