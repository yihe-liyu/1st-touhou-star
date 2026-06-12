# SpellRecordBook.gd
extends Resource
class_name SpellRecordBook

const SpellRecordClass = preload("res://scripts/data/spell_record.gd")

## 全符卡收取记录数组
@export var records: Array[Resource] = []

func get_record(spell_id: int):
	for r in records:
		if r.get("spell_id") == spell_id:
			return r
	return null

func record_attempt(spell_id: int, captured: bool, score: int, elapsed: float) -> void:
	var r = get_record(spell_id)
	if not r: return
	r.set("attempts", r.get("attempts") + 1)
	if captured:
		r.set("captures", r.get("captures") + 1)
		if score > r.get("best_score"):
			r.set("best_score", score)
		if elapsed > 0:
			var bt = r.get("best_time")
			if bt == 0 or elapsed < bt:
				r.set("best_time", elapsed)

func record_practice(spell_id: int, captured: bool) -> void:
	var r = get_record(spell_id)
	if not r: return
	r.set("practice_attempts", r.get("practice_attempts") + 1)
	if captured:
		r.set("practice_captures", r.get("practice_captures") + 1)

func get_capture_rate(spell_id: int) -> float:
	var r = get_record(spell_id)
	if not r: return 0.0
	var att: int = r.get("attempts")
	if att == 0: return 0.0
	return float(r.get("captures")) / float(att)

func get_history(spell_id: int) -> String:
	var r = get_record(spell_id)
	if not r: return "0/0"
	return "%d/%d" % [r.get("captures"), r.get("attempts")]
