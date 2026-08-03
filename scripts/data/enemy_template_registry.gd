class_name EnemyTemplateRegistry
extends RefCounted
## 敌人模板注册表 —— 数据与行为分离
##
## 三层结构：
##   数据层：EnemyData 构造链预设（enemy_data.gd：red_little_fairy / blue_middle_fairy
##           等 12 种 —— 外观/血量/判定/掉落）
##   行为层：移动+发弹脚本（独立注册 BEHAVIORS，可复用）
##   模板  ：数据 + 行为 组合（工作台下拉显示的就是模板名）
##
## 组合自由：同数据换行为（同外观不同弹幕）、同行为换数据（同弹幕不同强度）。
## 创作方式：新行为 = 注册 BEHAVIORS 一行；新数据 = 加 EnemyData 预设；新模板 = 组合一行。

const ENEMY01 := preload("res://data/stages/stage01/coroutine_script/enemy01.gd")
const ENEMY02 := preload("res://data/stages/stage01/coroutine_script/enemy02.gd")
const SWAY_FAIRY := preload("res://scripts/data/enemy_templates/sway_fairy.gd")

## 行为层：{行为名: {script, defaults(脚本参数默认)}}
const BEHAVIORS := {
	"aim_scatter": {"script": ENEMY01, "defaults": {"target_y": 300.0}},
	"middle_sweep": {"script": ENEMY02, "defaults": {"target_pos": Vector2(448, 300)}},
	"sway_aim": {"script": SWAY_FAIRY, "defaults": {"target_y": 260.0, "sway": 80.0, "bullet_n": 5, "fire_interval": 0.6}},
}

## 模板层：{模板名: {data(EnemyData 预设方法), behavior(行为名)}}
## data 来自 enemy_data.gd 的构造链预设；behavior 来自 BEHAVIORS
const TEMPLATES := {
	"red_little": {"data": "red_little_fairy", "behavior": "aim_scatter"},
	"red_middle": {"data": "red_middle_fairy", "behavior": "middle_sweep"},
	"sway_fairy": {"data": "blue_middle_fairy", "behavior": "sway_aim"},
	# ── 组合示例：同数据换行为 / 同行为换数据 ──
	"sway_red_little": {"data": "red_little_fairy", "behavior": "sway_aim"},
	"aim_blue_middle": {"data": "blue_middle_fairy", "behavior": "aim_scatter"},
}


## 按模板名构建 EnemyData（数据预设 + 行为脚本 + 默认参数）
static func build(name: String) -> EnemyData:
	var t: Dictionary = TEMPLATES.get(name, {})
	if t.is_empty():
		return null
	var data := EnemyData.new()
	# 数据层：EnemyData 构造链预设（外观/血量/判定/掉落）
	if t.has("data"):
		data.call(String(t.data))
	# 行为层：脚本 + 默认参数
	var b: Dictionary = BEHAVIORS.get(t.get("behavior", ""), {})
	if b.is_empty():
		push_warning("EnemyTemplateRegistry: 模板 %s 无行为" % name)
		return data
	if b.has("script"):
		data.script(b.script)
	for k in b.get("defaults", {}):
		data.param(k, b.defaults[k])
	return data


## 模板名列表（工作台下拉框用）
static func names() -> Array:
	var keys := TEMPLATES.keys()
	keys.sort()
	return keys


## 模板支持的参数（工作台"建议"按钮用）：行为 defaults 优先 + 反射脚本变量补全
static func suggest_params(name: String) -> Dictionary:
	var t: Dictionary = TEMPLATES.get(name, {})
	var result: Dictionary = {}
	if t.is_empty():
		return result
	var b: Dictionary = BEHAVIORS.get(t.get("behavior", ""), {})
	if b.is_empty():
		return result
	var d: Dictionary = b.get("defaults", {})
	for k in d:
		result[k] = d[k]
	# 反射脚本变量补全（排除私有/基类运行时变量）
	var script: Script = b.get("script")
	if script:
		var inst: Node = script.new()
		for p in inst.get_property_list():
			if not (p.usage & PROPERTY_USAGE_SCRIPT_VARIABLE):
				continue
			var pname: String = p.name
			if pname.begins_with("_") or pname in IGNORED_PARAMS or result.has(pname):
				continue
			result[pname] = inst.get(pname)
	return result


## 基类运行时变量（反射时排除，非用户参数）
const IGNORED_PARAMS := {
	"ctx": true, "target": true, "auto_stop": true, "config": true,
	"is_running": true, "_paused": true, "_fast_mode": true,
}
