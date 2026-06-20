extends Resource
class_name StageData

enum Difficulty { EASY, NORMAL, HARD, LUNATIC, EXTRA }

@export var stage_id: int = 1
@export var difficulty: Difficulty = Difficulty.NORMAL
@export var create_script: Script
@export var background_scene: PackedScene
@export var bosses: Array[BossData] = []   ## 本关卡所有 Boss（中 boss + 关底等）
