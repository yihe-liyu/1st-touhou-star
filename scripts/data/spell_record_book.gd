# SpellRecordBook.gd
extends Resource
class_name SpellRecordBook

const SpellRecordClass = preload("res://scripts/data/spell_record.gd")

## 全符卡收取记录
@export var records: Array[SpellRecord] = []

func get_record(ch: int, st: int, pt: int, pn: int, diff: int):
	for r in records:
		if r.character == ch and r.stage == st \
		   and r.phase_type == pt and r.phase_number == pn \
		   and r.difficulty == diff:
			return r
	return null

func record_attempt(ch: int, st: int, pt: int, pn: int, diff: int, captured: bool, score: int, elapsed: float, order: int = 0, uid: int = 0) -> void:
	var r = get_or_create(ch, st, pt, pn, diff, order, uid)
	if not r: return
	r.attempts += 1
	if captured:
		r.captures += 1
		if score > r.best_score:
			r.best_score = score
		if elapsed > 0:
			if r.best_time == 0 or elapsed < r.best_time:
				r.best_time = elapsed

func record_practice(ch: int, st: int, pt: int, pn: int, diff: int, captured: bool, order: int = 0) -> void:
	var r = get_or_create(ch, st, pt, pn, diff, order)
	if not r: return
	r.practice_attempts += 1
	if captured:
		r.practice_captures += 1

func get_or_create(ch: int, st: int, pt: int, pn: int, diff: int, order: int = 0, uid: int = 0):
	var r = get_record(ch, st, pt, pn, diff)
	if r: return r
	r = SpellRecordClass.new()
	r.character = ch
	r.stage = st
	r.phase_type = pt
	r.phase_number = pn
	r.difficulty = diff
	if order > 0:
		r.phase_order = order
	if uid > 0:
		r.spell_uid = uid
	records.append(r)
	return r

func get_by_stage(ch: int, st: int) -> Array[SpellRecord]:
	var result: Array[SpellRecord] = []
	for r in records:
		if r.character == ch and r.stage == st:
			result.append(r)
	return result

func get_history(ch: int, st: int, pt: int, pn: int, diff: int) -> String:
	var r = get_record(ch, st, pt, pn, diff)
	if not r: return "0/0"
	return "%d/%d" % [r.captures, r.attempts]
