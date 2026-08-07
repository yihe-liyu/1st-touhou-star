# SpellRecord.gd
extends Resource
class_name SpellRecord

enum Character { REIMU, MARISA }
const CHAR_NAMES := ["博丽灵梦", "雾雨魔理沙"]

enum Difficulty { EASY, NORMAL, HARD, LUNATIC, EXTRA }
const DIFF_VALUES := [0, 1, 2, 3, 4]
const DIFF_NAMES := ["Easy", "Normal", "Hard", "Lunatic", "Extra"]

enum PhaseType { NONSPELL, SPELL }

## 展示用编号（如 "No.001"），纯装饰，不参与查重
@export var uid: int = 0
## 角色 0=Reimu 1=Marisa
@export var character: int = 0
## 关卡编号
@export var stage: int = 1
## 在该关卡 phases 数组中的索引（唯一标识 phase）
@export var phase_index: int = -1
## 非符/符卡
@export var phase_type: int = 0
## 第几张非符/第几张符卡（展示用）
@export var phase_number: int = 1
## 难度
@export var difficulty: int = 1
## 符卡名（非符也存）
@export var name: String = ""
## 第几个 Boss（多 Boss 关卡区分记录；0 = 第一个/唯一）
@export var boss_index: int = 0
## 战斗配置（血量/脚本/时限等）——解锁时自动存，练习菜单直接使用（无需 CardDef）
@export var phase_data: PhaseData
## Boss 视觉——解锁时自动存（练习时 Boss 外观）
@export var boss_scene: PackedScene
## 尝试次数（普通模式）
@export var attempts: int = 0
## 收取次数（普通模式）
@export var captures: int = 0
## 练习尝试次数
@export var practice_attempts: int = 0
## 练习收取次数
@export var practice_captures: int = 0
## 最高分
@export var best_score: int = 0
## 最快时间
@export var best_time: float = 0.0
