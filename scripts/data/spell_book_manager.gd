class_name SpellBookManager
extends RefCounted
## 符卡簿管理：加载/保存/解锁/记录（从 GameState 拆出，职责单一）

const SPELL_BOOK_PATH := "res://data/registry/spell_records.tres"

var spell_book: SpellRecordBook


func load() -> void:
	spell_book = ResourceLoader.load(SPELL_BOOK_PATH)
	if spell_book:
		# 防御：清理幽灵记录并落盘（编辑器旧数据写回的空壳不留）
		var before: int = spell_book.records.size()
		spell_book.prune_empty()
		if spell_book.records.size() != before:
			save()


func save() -> void:
	if spell_book:
		spell_book.prune_empty()
	ResourceSaver.save(spell_book, SPELL_BOOK_PATH)


## 注册一张符卡（见到即记，不计 attempt）
func unlock_spell(pid: PhaseIdentity) -> void:
	spell_book.get_or_create(pid.stage_id, pid.phase_index, pid.character, pid.difficulty,
		pid.uid, pid.phase_type, pid.phase_number, pid.name)
	save()


## 记录一次符卡尝试（普通模式）
func record_spell(pid: PhaseIdentity, captured: bool, score: int, elapsed: float) -> void:
	spell_book.record_attempt(pid.stage_id, pid.phase_index, pid.character, pid.difficulty,
		captured, score, elapsed, {
		"uid": pid.uid, "phase_type": pid.phase_type, "phase_number": pid.phase_number, "name": pid.name,
	})
	save()


## 记录一次练习尝试
func record_practice(pid: PhaseIdentity, captured: bool) -> void:
	spell_book.record_practice(pid.stage_id, pid.phase_index, pid.character, pid.difficulty, captured)
	save()
