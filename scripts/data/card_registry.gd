extends Resource
class_name CardRegistry
## 符卡注册表——所有可练习的符卡定义

@export var cards: Array[CardDef] = []


## 按 (uid, stage_id, difficulty, character) 查找
func find(uid: int, stage_id: int, difficulty: int = -1, character: int = -1) -> CardDef:
	for c in cards:
		if c.uid == uid and c.stage_id == stage_id:
			if difficulty != -1 and c.difficulty != -1 and c.difficulty != difficulty:
				continue
			if character != -1 and c.character != -1 and c.character != character:
				continue
			return c
	return null


## 按关卡获取所有符卡
func get_by_stage(stage_id: int) -> Array[CardDef]:
	var result: Array[CardDef] = []
	for c in cards:
		if c.stage_id == stage_id:
			result.append(c)
	return result
