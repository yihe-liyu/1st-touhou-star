# SpellRecord.gd
extends Resource
class_name SpellRecord

@export var spell_id: String = ""        ## 符卡唯一ID，对应 PhaseData.spell_id
@export var attempts: int = 0            ## 挑战次数
@export var captures: int = 0            ## 收取次数
@export var best_score: int = 0          ## 最高奖励分
@export var best_time: float = 0.0       ## 最快击破时间（秒）
