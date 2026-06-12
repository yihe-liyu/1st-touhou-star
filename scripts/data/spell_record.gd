# SpellRecord.gd
extends Resource
class_name SpellRecord

enum Character { REIMU, MARISA }
const CHAR_NAMES := ["博丽灵梦", "雾雨魔理沙"]

enum Difficulty { EASY, NORMAL, HARD, LUNATIC }
const DIFF_NAMES := ["Easy", "Normal", "Hard", "Lunatic"]

@export var character: int = 0           ## 角色 0=Reimu 1=Marisa
@export var stage: int = 1               ## 关卡号
@export var phase: int = 1               ## 第几张符卡/非符（从1开始）
@export var difficulty: int = 1          ## 难度 0=Easy 1=Normal 2=Hard 3=Lunatic
@export var spell_name: String = ""      ## 符卡名（显示用）
@export var attempts: int = 0            ## 挑战次数（故事）
@export var captures: int = 0            ## 收取次数（故事）
@export var practice_attempts: int = 0   ## 练习挑战次数
@export var practice_captures: int = 0   ## 练习收取次数
@export var best_score: int = 0          ## 最高奖励分
@export var best_time: float = 0.0       ## 最快击破（秒）
