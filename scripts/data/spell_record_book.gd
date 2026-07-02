# SpellRecordBook.gd
extends Resource
class_name SpellRecordBook

const SpellRecordClass = preload("res://scripts/data/spell_record.gd")

## 全符卡记录，主键 (uid, character, difficulty)
@export var records: Array[SpellRecord] = []


func get_record(uid: int, character: int, difficulty: int) -> SpellRecord:
	for r in records:
		if r.uid == uid and r.character == character and r.difficulty == difficulty:
			return r
	return null


func get_or_create(uid: int, character: int, difficulty: int,
		stage: int = 1, phase_type: int = 0, phase_num: int = 1,
		order: int = 0, sname: String = "") -> SpellRecord:
	var r := get_record(uid, character, difficulty)
	if r: return r
	r = SpellRecordClass.new()
	r.uid = uid
	r.character = character
	r.difficulty = difficulty
	r.stage = stage
	r.phase_type = phase_type
	r.phase_number = phase_num
	if order > 0: r.phase_order = order
	if sname != "": r.spell_name = sname
	records.append(r)
	return r


func record_attempt(uid: int, character: int, difficulty: int, captured: bool,
		score: int, elapsed: float, extra: Dictionary = {}) -> void:
	var r := get_or_create(uid, character, difficulty,
		extra.get("stage", 1), extra.get("phase_type", 0),
		extra.get("phase_num", 1), extra.get("order", 0), extra.get("name", ""))
	r.attempts += 1
	if captured:
		r.captures += 1
		if score > r.best_score:
			r.best_score = score
		if elapsed > 0:
			if r.best_time == 0 or elapsed < r.best_time:
				r.best_time = elapsed


func record_practice(uid: int, character: int, difficulty: int, captured: bool,
		extra: Dictionary = {}) -> void:
	var r := get_or_create(uid, character, difficulty,
		extra.get("stage", 1), extra.get("phase_type", 0),
		extra.get("phase_num", 1), extra.get("order", 0), extra.get("name", ""))
	r.practice_attempts += 1
	if captured:
		r.practice_captures += 1


## 返回指定 uid 的 records（所有角色所有难度）
func get_by_uid(uid: int) -> Array[SpellRecord]:
	var result: Array[SpellRecord] = []
	for r in records:
		if r.uid == uid:
			result.append(r)
	return result


## 返回某角色在某关卡的全部记录（按 phase_order 排序）
func get_by_stage(character: int, stage_id: int) -> Array[SpellRecord]:
	var result: Array[SpellRecord] = []
	for r in records:
		if r.character == character and r.stage == stage_id:
			result.append(r)
	result.sort_custom(func(a, b): return a.phase_order < b.phase_order)
	return result


func get_history(uid: int, character: int, difficulty: int) -> String:
	var r := get_record(uid, character, difficulty)
	if not r: return "0/0"
	return "%d/%d" % [r.captures, r.attempts]
