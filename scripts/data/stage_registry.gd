# StageRegistry.gd — 全关卡注册表
extends Resource
class_name StageRegistry

## 所有关卡资源（所有难度 × 所有关卡）
@export var stages: Array[StageData] = []


## 按 (stage_id, difficulty) 查找
func find(stage_id: int, difficulty: int) -> StageData:
	for s in stages:
		if s.stage_id == stage_id and (s.difficulty == difficulty or s.difficulty == -1):
			return s
	return null


## 按 stage_id 获取所有难度版本
func get_by_stage(stage_id: int) -> Array[StageData]:
	var result: Array[StageData] = []
	for s in stages:
		if s.stage_id == stage_id:
			result.append(s)
	return result


## 用于符卡练习：遍历所有关卡的所有 BossData
func for_each_boss(callback: Callable) -> void:
	for s in stages:
		for boss in s.bosses:
			callback.call(boss, s.stage_id, s.difficulty)
