class_name PhaseIdentity
extends RefCounted
## 一个 phase（非符/符卡）的唯一身份标识
##
## 用于在 GameState 各记录方法之间传递身份信息，
## 避免各处重复拼装参数。

var uid: int
var character: int
var difficulty: int
var stage_id: int
var phase_type: int  # SpellRecord.PhaseType
var phase_num: int   # 第几张非符/第几张符卡
var phase_order: int # 在 phases 数组中的索引
var name: String     # 符卡名，非符可为空


## 从 Boss 运行时的 PhaseData + 上下文推导
static func from_phase(phase: PhaseData, p_stage_id: int, phase_idx: int,
		spell_count: int, non_count: int) -> PhaseIdentity:
	var pid := PhaseIdentity.new()
	var is_spell := phase.uid != 0
	pid.uid = SpellRecord.get_phase_uid(null, phase_idx, p_stage_id, phase)
	pid.character = GameState.selected_character
	pid.difficulty = GameState.selected_difficulty
	pid.stage_id = p_stage_id
	pid.phase_type = SpellRecord.PhaseType.SPELL if is_spell else SpellRecord.PhaseType.NONSPELL
	pid.phase_num = spell_count if is_spell else non_count
	pid.phase_order = phase_idx
	pid.name = phase.name
	return pid


## 从 CardDef（编辑器注册）推导
static func from_card_def(card: CardDef) -> PhaseIdentity:
	var pid := PhaseIdentity.new()
	pid.uid = card.uid
	pid.character = card.character if card.character >= 0 else GameState.selected_character
	pid.difficulty = card.difficulty if card.difficulty >= 0 else GameState.selected_difficulty
	pid.stage_id = card.stage_id
	pid.phase_type = SpellRecord.PhaseType.SPELL
	pid.phase_order = card.order
	pid.name = card.name
	return pid
