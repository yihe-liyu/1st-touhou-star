# StageRegistry.gd — 全关卡注册表
extends Resource
class_name StageRegistry

@export var stages: Array[StageData] = []  ## 所有关卡（一个 stage_id 一个文件）


## 按 stage_id 查找
func find(stage_id: int) -> StageData:
	for s in stages:
		if s.stage_id == stage_id:
			return s
	return null


## 获取所有关卡
func get_all() -> Array[StageData]:
	return stages
