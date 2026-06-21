# BossData.gd
## Boss 定义：名称 + 视觉场景 + 阶段（非符+符卡）列表
extends Resource
class_name BossData

@export var boss_name: String = ""  ## Boss 名字（左上角显示）
@export var visual: PackedScene          ## Boss 外观场景
@export var phases: Array[PhaseData] = [] ## 阶段列表（含非符+符卡）
@export var score_value: int = 10000     ## 击破总分（最后一个 phase）
