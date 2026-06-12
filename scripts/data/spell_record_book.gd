# SpellRecordBook.gd
extends Resource
class_name SpellRecordBook

const SpellRecordClass = preload("res://scripts/data/spell_record.gd")

@export var records: Dictionary = {}  # spell_id → SpellRecord

func get_record(spell_id: String):
	return records.get(spell_id, null)

func record_attempt(spell_id: String, captured: bool, score: int, elapsed: float) -> void:
	var r = get_record(spell_id)
	if not r: return
	r.attempts += 1
	if captured:
		r.captures += 1
		if score > r.best_score:
			r.best_score = score
		if elapsed > 0 and (r.best_time == 0 or elapsed < r.best_time):
			r.best_time = elapsed

func get_capture_rate(spell_id: String) -> float:
	var r = get_record(spell_id)
	if r.attempts == 0:
		return 0.0
	return float(r.captures) / float(r.attempts)

func get_history(spell_id: String) -> String:
	var r = get_record(spell_id)
	return "%d/%d" % [r.captures, r.attempts]
