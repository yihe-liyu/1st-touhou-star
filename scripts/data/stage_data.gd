extends Resource
## 关卡定义：id + 脚本 + 背景 + 可选 Boss（数据关卡用）
## 难度差分在 CoroutineScript 中通过 diff_pick() / diff_get() 运行时处理
class_name StageData

@export var stage_id: int = 1
@export var create_script: Script
@export var background_scene: PackedScene
## 数据关卡的编排数据（波次表 + 演出事件；协程关卡忽略）
## 数据关卡用它替代 create_script 里的 TIMELINE 常量
@export var timeline: StageTimeline
## 数据关卡的 Boss（可选；协程关卡在代码里编排，忽略此字段）
@export var boss: BossData
@export var boss_time: float = 35.0   ## Boss 出现时刻（秒）
## 多 Boss（可选；中 Boss = 打完退场的非最终）：每项 {boss: BossData, t: 出现时刻}
@export var bosses: Array = []


## 合并后的 Boss 列表（旧 boss/boss_time 字段 + bosses 数组去重），按出现时间升序
func all_bosses() -> Array:
	var list: Array = []
	if boss:
		list.append({"boss": boss, "t": boss_time})
	for entry in bosses:
		if entry and entry.get("boss") != null:
			var dup := false
			for e in list:
				if e["boss"] == entry["boss"]:
					dup = true
					break
			if not dup:
				list.append({"boss": entry["boss"], "t": float(entry.get("t", 0.0))})
	list.sort_custom(func(a: Dictionary, b: Dictionary): return a["t"] < b["t"])
	return list


## 配置校验：返回错误列表（空 = 合法）
func validate() -> Array[String]:
	var errs: Array[String] = []
	if stage_id < 1:
		errs.append("StageData.stage_id = %s 必须 >= 1" % stage_id)
	if create_script == null:
		errs.append("StageData[%d] 缺少 create_script（关卡无法生成）" % stage_id)
	# Boss 数据校验（time_limit<=0 会导致一出场就超时 → 掉道具/闪退）
	for entry in all_bosses():
		var bd: BossData = entry["boss"]
		if bd:
			errs.append_array(bd.validate())
	return errs
