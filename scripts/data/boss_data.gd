# BossData.gd
extends Resource
class_name BossData

@export var visual: PackedScene          ## Boss 外观场景
@export var phases: Array[PhaseData] = [] ## 阶段列表（含非符+符卡）
@export var score_value: int = 10000     ## 击破总分（最后一个 phase）
