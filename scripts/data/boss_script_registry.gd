class_name BossScriptRegistry
extends RefCounted
## Boss 阶段脚本注册表：移动/弹幕脚本选择 + 反射参数
## 工作台符卡编辑器下拉用；新移动/弹幕脚本注册一行即可出现
## 脚本内 var 自动反射为参数（工作台建议按钮），运行时经 PhaseData.params 注入

const MOVE_SCRIPTS := {
	"非符·定点": preload("res://data/stages/stage01/coroutine_script/boss/non_01_move.gd"),
}
const SHOOT_SCRIPTS := {
	"非符·圆环弹": preload("res://data/stages/stage01/coroutine_script/boss/non_01_shoot.gd"),
}
## 入场/退场演出脚本（Boss 战斗外的行为自由度）
const ENTER_SCRIPTS := {
	"侧面入场（stage01风）": preload("res://scripts/data/boss_scripts/enter_side.gd"),
}
const EXIT_SCRIPTS := {
	"退场·右飞出": preload("res://scripts/data/boss_scripts/exit_side.gd"),
}


static func move_names() -> Array:
	var keys := MOVE_SCRIPTS.keys()
	keys.sort()
	return keys


static func shoot_names() -> Array:
	var keys := SHOOT_SCRIPTS.keys()
	keys.sort()
	return keys


static func move_script(name: String) -> Script:
	return MOVE_SCRIPTS.get(name, null)


static func shoot_script(name: String) -> Script:
	return SHOOT_SCRIPTS.get(name, null)


static func enter_names() -> Array:
	var keys := ENTER_SCRIPTS.keys()
	keys.sort()
	return keys


static func exit_names() -> Array:
	var keys := EXIT_SCRIPTS.keys()
	keys.sort()
	return keys


static func enter_script(name: String) -> Script:
	return ENTER_SCRIPTS.get(name, null)


static func exit_script(name: String) -> Script:
	return EXIT_SCRIPTS.get(name, null)


## 脚本参数建议（反射脚本变量，排除私有/基类运行时变量）
static func suggest_params(script: Script) -> Dictionary:
	if script == null:
		return {}
	var result: Dictionary = {}
	var inst: Node = script.new()
	for p in inst.get_property_list():
		if not (p.usage & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		var pname: String = p.name
		if pname.begins_with("_") or pname in IGNORED_PARAMS:
			continue
		result[pname] = inst.get(pname)
	return result


## 基类运行时变量（反射时排除，非用户参数）
const IGNORED_PARAMS := {
	"ctx": true, "target": true, "auto_stop": true, "config": true,
	"is_running": true, "_paused": true, "_fast_mode": true,
}
