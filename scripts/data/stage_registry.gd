# StageRegistry.gd — 全关卡注册表
extends Resource
class_name StageRegistry

## 所有关卡资源（所有难度 × 所有关卡）
@export var stages: Array[StageData] = []


## 按 (stage_id, difficulty) 查找
func find(stage_id: int, difficulty: int) -> StageData:
	for s in stages:
		if s.stage_id == stage_id and s.difficulty == difficulty:
			return s
	return null


## 按 stage_id 获取所有难度版本
func get_by_stage(stage_id: int) -> Array[StageData]:
	var result: Array[StageData] = []
	for s in stages:
		if s.stage_id == stage_id:
			result.append(s)
	return result
