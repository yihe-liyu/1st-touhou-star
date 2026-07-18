extends Resource
## 关卡定义：id + 脚本 + 背景
## 难度差分在 CoroutineScript 中通过 diff_pick() / diff_get() 运行时处理
class_name StageData

@export var stage_id: int = 1
@export var create_script: Script
@export var background_scene: PackedScene
