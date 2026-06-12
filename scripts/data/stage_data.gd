extends Resource
class_name StageData

@export var stage_id: int = 1
@export var stage_name: String = "Stage 1"
@export var create_script: Script
@export var background_scene: PackedScene
@export var bgm: AudioStream                ## 关卡 BGM
@export var next_stage: StageData           ## 通关后下一关
