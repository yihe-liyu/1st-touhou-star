# SpellRecord.gd
extends Resource
class_name SpellRecord

@export var spell_id: String = ""
@export var phase_data: PhaseData  # 符卡数据引用，练习模式用
@export var boss_data: BossData    # Boss 数据引用（视觉等）
@export var attempts: int = 0
@export var captures: int = 0
@export var best_score: int = 0
@export var best_time: float = 0.0
