extends Resource
class_name StageData

enum Difficulty { EASY, NORMAL, HARD, LUNATIC, EXTRA }

@export var stage_id: int = 1
@export var difficulty: Difficulty = Difficulty.NORMAL
@export var create_script: Script
@export var background_scene: PackedScene
