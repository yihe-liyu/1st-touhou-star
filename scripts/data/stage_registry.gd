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


## 全关卡校验：查重 + 逐个校验。返回错误列表（空 = 合法）
func validate() -> Array[String]:
	var errs: Array[String] = []
	var seen: Dictionary = {}
	for st in stages:
		if st == null:
			errs.append("StageRegistry 含空 StageData 条目")
			continue
		if seen.has(st.stage_id):
			errs.append("StageRegistry 中 stage_id = %d 重复" % st.stage_id)
		seen[st.stage_id] = true
		errs.append_array(st.validate())
	return errs
