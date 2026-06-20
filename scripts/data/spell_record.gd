# SpellRecord.gd
extends Resource
class_name SpellRecord

enum Character { REIMU, MARISA }
const CHAR_NAMES := ["博丽灵梦", "雾雨魔理沙"]

enum Difficulty { EASY=1, NORMAL=2, HARD=4, LUNATIC=8, EXTRA=16 }
const DIFF_VALUES := [1, 2, 4, 8, 16]
const DIFF_NAMES := ["Easy", "Normal", "Hard", "Lunatic", "Extra"]

enum PhaseType { NONSPELL, SPELL }

## 给非符卡生成合成 uid（stage*100 + phase_idx + 1 取负）
static func make_non_uid(stage_id: int, phase_idx: int) -> int:
	return -(stage_id * 100 + phase_idx + 1)

## 从 boss 数据获取 phase 的 uid（真 uid 或合成 uid）
static func get_phase_uid(boss: BossData, phase_idx: int, stage_id: int) -> int:
	var phase := boss.phases[phase_idx]
	if phase.uid != 0:
		return phase.uid
	return make_non_uid(stage_id, phase_idx)

## 符卡 uid（唯一标识，非符卡由系统生成负号区分）
@export var uid: int = 0
@export var character: int = 0
@export var stage: int = 1
@export var phase_type: int = 0
@export var phase_number: int = 1
@export var difficulty: int = 1
@export var spell_name: String = ""
@export var phase_order: int = 1
@export var attempts: int = 0
@export var captures: int = 0
@export var practice_attempts: int = 0
@export var practice_captures: int = 0
@export var best_score: int = 0
@export var best_time: float = 0.0
