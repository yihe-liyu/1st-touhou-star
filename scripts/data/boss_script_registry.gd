class_name BossScriptRegistry
extends RefCounted
## Boss 阶段脚本注册表：移动/弹幕/入场/退场脚本选择 + 反射参数
## 工作台符卡编辑器下拉 + 脚本页签用；脚本内 var 自动反射为参数
##
## 两种来源（自动合并，工作台无感知）：
##   1. 目录自动发现（推荐，零注册）：
##        data/boss_scripts/move/   ← 移动脚本 .gd 扔进来即出现
##        data/boss_scripts/shoot/  ← 弹幕脚本
##        data/boss_scripts/enter/  ← 入场演出
##        data/boss_scripts/exit/   ← 退场演出
##      文件名（去 .gd）= 显示名
##   2. 手动注册（兼容旧脚本/需要显示名与文件名不同时）：
##        KINDS 里 manual 表，一行 = 名字 + 路径
##
## 新脚本 = 写 .gd → 扔进对应目录 → 工作台下拉/脚本页自动出现，无需改代码

## 四类：{kind: {dir(自动发现目录), manual(手动注册表：名字→路径)}}
const KINDS := {
	"move": {
		"dir": "res://data/boss_scripts/move",
		"manual": {
			"非符·定点": "res://data/stages/stage01/coroutine_script/boss/non_01_move.gd",
		},
	},
	"shoot": {
		"dir": "res://data/boss_scripts/shoot",
		"manual": {
			"非符·圆环弹": "res://data/stages/stage01/coroutine_script/boss/non_01_shoot.gd",
		},
	},
	"enter": {
		"dir": "res://data/boss_scripts/enter",
		"manual": {
			"侧面入场（stage01风）": "res://scripts/data/boss_scripts/enter_side.gd",
		},
	},
	"exit": {
		"dir": "res://data/boss_scripts/exit",
		"manual": {
			"退场·右飞出": "res://scripts/data/boss_scripts/exit_side.gd",
		},
	},
}

## 运行时脚本缓存（path → Script）；reload_path 后失效重载（同 EnemyTemplateRegistry）
static var _script_cache: Dictionary = {}


## 类内条目 [{name, path}]：manual 表 + 目录扫描合并，按名字排序
static func _entries(kind: String) -> Array[Dictionary]:
	var k: Dictionary = KINDS.get(kind, {})
	if k.is_empty():
		return []
	var items: Array[Dictionary] = []
	var seen := {}
	for n in k.get("manual", {}):
		items.append({"name": str(n), "path": str(k["manual"][n])})
		seen[str(n)] = true
	var dir := str(k.get("dir", ""))
	var d := DirAccess.open(dir)
	if d:
		d.list_dir_begin()
		var f := d.get_next()
		while f != "":
			if not d.current_is_dir() and f.ends_with(".gd"):
				var nm := f.trim_suffix(".gd")
				if not seen.has(nm):
					items.append({"name": nm, "path": "%s/%s" % [dir, f]})
			f = d.get_next()
		d.list_dir_end()
	items.sort_custom(func(a: Dictionary, b: Dictionary): return str(a.get("name", "")) < str(b.get("name", "")))
	return items


## 名字 → 路径（manual 优先，目录扫描兜底）
static func _path_of(kind: String, name: String) -> String:
	for e in _entries(kind):
		if str(e.get("name", "")) == name:
			return str(e.get("path", ""))
	return ""


## 类内名字列表
static func _names(kind: String) -> Array:
	var out: Array = []
	for e in _entries(kind):
		out.append(e.name)
	return out


## 按名字取脚本（运行时 load + 缓存；编译失败时重试 load）
static func _script(kind: String, name: String) -> Script:
	var path := _path_of(kind, name)
	if path.is_empty():
		return null
	if not _script_cache.has(path):
		_script_cache[path] = load(path)
	return _script_cache[path]


static func move_names() -> Array:
	return _names("move")


static func shoot_names() -> Array:
	return _names("shoot")


static func enter_names() -> Array:
	return _names("enter")


static func exit_names() -> Array:
	return _names("exit")


static func move_script(name: String) -> Script:
	return _script("move", name)


static func shoot_script(name: String) -> Script:
	return _script("shoot", name)


static func enter_script(name: String) -> Script:
	return _script("enter", name)


static func exit_script(name: String) -> Script:
	return _script("exit", name)


## 公开：某类的 [{name, path}]（工作台脚本页签分类数据源）
static func entries_for(kind: String) -> Array[Dictionary]:
	return _entries(kind)


## 四类全部 [{kind, name, path}]（工作台脚本页签数据源）
static func all_paths() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for kind in KINDS:
		for e in _entries(kind):
			out.append({"kind": kind, "name": e.name, "path": e.path})
	out.sort_custom(func(a: Dictionary, b: Dictionary): return str(a.name) < str(b.name))
	return out


## 路径是否属于本注册表（reload 分派用）
static func has_path(path: String) -> bool:
	for e in all_paths():
		if str(e.get("path", "")) == path:
			return true
	return false


## 热重载（CACHE_MODE_IGNORE 强制重编译；同 EnemyTemplateRegistry.reload_behavior）
static func reload_path(path: String) -> bool:
	var s: Script = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if s == null:
		return false
	_script_cache[path] = s
	return true


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
