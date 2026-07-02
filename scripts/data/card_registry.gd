extends Resource
class_name CardRegistry
## 符卡注册表——所有可练习的符卡定义
## 卡片在数组中的顺序不重要，按 order + stage_id 排序

@export var cards: Array[CardDef] = []


## 按关卡获取所有符卡（按 order 排序）
func get_by_stage(stage_id: int) -> Array[CardDef]:
	var result: Array[CardDef] = []
	for c in cards:
		if c.stage_id == stage_id:
			result.append(c)
	result.sort_custom(func(a, b): return a.order < b.order)
	return result


## 获取所有有关卡的 id（按数字排序）
func get_stage_ids() -> Array[int]:
	var seen: Dictionary = {}
	for c in cards:
		seen[c.stage_id] = true
	var ids: Array[int] = []
	for k in seen.keys():
		ids.append(k)
	ids.sort()
	return ids
