# SpellRecord.gd
extends Resource
class_name SpellRecord

enum Character { REIMU, MARISA }
const CHAR_NAMES := ["博丽灵梦", "雾雨魔理沙"]

enum Difficulty { EASY, NORMAL, HARD, LUNATIC, EXTRA }
const DIFF_NAMES := ["Easy", "Normal", "Hard", "Lunatic", "Extra"]

enum PhaseType { NONSPELL, SPELL }

@export_group("Key")
@export var spell_uid: int = 0                         ## 全局唯一符卡编号
@export var character: Character = Character.REIMU     ## 角色
@export var stage: int = 1                             ## 关卡号
@export var phase_type: PhaseType = PhaseType.SPELL    ## 非符/符卡
@export var phase_number: int = 1                      ## 第几个非符/符卡
@export var difficulty: Difficulty = Difficulty.NORMAL ## 难度
@export var spell_name: String = ""                    ## 符卡名
@export var phase_order: int = 1                       ## 出场顺序（1=第一个出的）

@export_group("Story")
@export var attempts: int = 0                          ## 挑战次数
@export var captures: int = 0                          ## 收取次数

@export_group("Practice")
@export var practice_attempts: int = 0                 ## 练习挑战次数
@export var practice_captures: int = 0                 ## 练习收取次数

@export_group("Best")
@export var best_score: int = 0                        ## 最高奖励分
@export var best_time: float = 0.0                     ## 最快击破（秒）
