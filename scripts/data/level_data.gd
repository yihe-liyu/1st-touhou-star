extends Resource
class_name LevelData

## 关卡编号
@export var stage_id: int = 1
## 关卡名称
@export var stage_name: String = "Stage 1"
## 波次列表
@export var waves: Array[WaveData] = []
## 背景音乐路径（预留）
@export var bgm_path: String = ""
## 背景配置数据
@export var background_data: StageBackgroundData
## 难度倍率
@export var difficulty_mult: float = 1.0
