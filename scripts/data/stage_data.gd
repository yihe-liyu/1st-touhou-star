extends Resource
class_name StageData

enum Difficulty { EASY=1, NORMAL=2, HARD=4, LUNATIC=8, EXTRA=16 }

@export var stage_id: int = 1
@export_flags("EASY:1", "NORMAL:2", "HARD:4", "LUNATIC:8", "EXTRA:16") var difficulty: int = Difficulty.NORMAL
@export var create_script: Script
@export var background_scene: PackedScene
@export var bosses: Array[BossData] = []   ## 本关卡所有 Boss（中 boss + 关底等）
