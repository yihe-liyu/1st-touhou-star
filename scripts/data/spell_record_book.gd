# SpellRecordBook.gd
extends Resource
class_name SpellRecordBook

const SpellRecordClass = preload("res://scripts/data/spell_record.gd")

## 全符卡收取记录
@export var records: Array[Resource] = []

func get_record(ch: int, st: int, pt: int, pn: int, diff: int):
	for r in records:
		if r.get("character") == ch and r.get("stage") == st \
		   and r.get("phase_type") == pt and r.get("phase_number") == pn \
		   and r.get("difficulty") == diff:
			return r
	return null

func record_attempt(ch: int, st: int, pt: int, pn: int, diff: int, captured: bool, score: int, elapsed: float, order: int = -1) -> void:
	var r = get_or_create(ch, st, pt, pn, diff, order)
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

func record_practice(ch: int, st: int, pt: int, pn: int, diff: int, captured: bool, order: int = -1) -> void:
	var r = get_or_create(ch, st, pt, pn, diff, order)
	if not r: return
	r.set("practice_attempts", r.get("practice_attempts") + 1)
	if captured:
		r.set("practice_captures", r.get("practice_captures") + 1)

func get_or_create(ch: int, st: int, pt: int, pn: int, diff: int, order: int = 0, uid: int = 0):
	var r = get_record(ch, st, pt, pn, diff)
	if r: return r
	r = SpellRecordClass.new()
	r.set("character", ch)
	r.set("stage", st)
	r.set("phase_type", pt)
	r.set("phase_number", pn)
	r.set("difficulty", diff)
	if order > 0:
		r.set("phase_order", order)
	if uid > 0:
		r.set("spell_uid", uid)
	records.append(r)
	return r

func get_by_stage(ch: int, st: int) -> Array:
	var result: Array = []
	for r in records:
		if r.get("character") == ch and r.get("stage") == st:
			result.append(r)
	return result

func get_history(ch: int, st: int, pt: int, pn: int, diff: int) -> String:
	var r = get_record(ch, st, pt, pn, diff)
	if not r: return "0/0"
	return "%d/%d" % [r.get("captures"), r.get("attempts")]
