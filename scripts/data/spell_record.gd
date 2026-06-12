# SpellRecord.gd
extends Resource
class_name SpellRecord

@export var spell_id: int = 0        ## 符卡唯一ID，对应 PhaseData.spell_id
@export var attempts: int = 0            ## 挑战次数
@export var captures: int = 0            ## 收取次数（故事模式）
@export var practice_attempts: int = 0   ## 练习模式挑战次数
@export var practice_captures: int = 0   ## 练习模式收取次数
@export var best_score: int = 0          ## 最高奖励分
@export var best_time: float = 0.0       ## 最快击破时间（秒）
