# BossData.gd
extends Resource
class_name BossData

@export var visual: PackedScene
@export var phases: Array[PhaseData] = []
@export var score_value: int = 10000
