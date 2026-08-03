class_name EnemyTemplateRegistry
extends RefCounted
## 敌人数据/行为注册表 —— 自由组合
##
##   数据层：data/enemy_presets/*.tres（EnemyData 预设：外观/血量/判定/掉落）
##   行为层：BEHAVIORS（移动+发弹脚本，可复用）
##   组合：build_from(数据名, 行为名) —— 同数据换行为 / 同行为换数据
## 创作方式：新行为 = 注册 BEHAVIORS 一行；新数据 = 复制 .tres。

const ENEMY01 := preload("res://data/stages/stage01/coroutine_script/enemy01.gd")
const ENEMY02 := preload("res://data/stages/stage01/coroutine_script/enemy02.gd")
const SWAY_FAIRY := preload("res://scripts/data/enemy_templates/sway_fairy.gd")
const ENEMY_DATA_SCRIPT := preload("res://scripts/data/enemy_data.gd")
const PRESET_DIR := "res://data/enemy_presets"

## 行为层：{行为名: {script, defaults(脚本参数默认)}}
const BEHAVIORS := {
	"aim_scatter": {"script": ENEMY01, "defaults": {"target_y": 300.0}},
	"middle_sweep": {"script": ENEMY02, "defaults": {"target_pos": Vector2(448, 300)}},
	"sway_aim": {"script": SWAY_FAIRY, "defaults": {"target_y": 260.0, "sway": 80.0, "bullet_n": 5, "fire_interval": 0.6}},
}

## 数据预设名列表：读 data/enemy_presets/*.tres（新增预设 = 复制 .tres，无需代码）
## 兜底：目录为空时反射构造链方法（兼容开发中状态）
static func data_names() -> Array:
	var preset_names: Array = []
	var d := DirAccess.open(PRESET_DIR)
	if d:
		d.list_dir_begin()
		var f := d.get_next()
		while f != "":
			if not d.current_is_dir() and f.ends_with(".tres"):
				preset_names.append(f.trim_suffix(".tres"))
			f = d.get_next()
		d.list_dir_end()
	if preset_names.is_empty():
		return _method_preset_names()
	preset_names.sort()
	return preset_names


## 反射 EnemyData 构造链方法（兜底）
static func _method_preset_names() -> Array:
	var preset_names: Array = []
	var scr: Script = ENEMY_DATA_SCRIPT
	for m in scr.get_script_method_list():
		var mn: String = m.name
		if mn.ends_with("_fairy") or mn.ends_with("_jade"):
			preset_names.append(mn)
	preset_names.sort()
	return preset_names


## 行为名列表
static func behavior_names() -> Array:
	var keys := BEHAVIORS.keys()
	keys.sort()
	return keys


## 自由组合：数据预设 × 行为（工作台两个下拉任意搭配）
## 数据预设：data/enemy_presets/*.tres 优先，构造链方法兜底
static func build_from(data_name: String, behavior_name: String) -> EnemyData:
	var data := _load_preset(data_name)
	if data == null:
		return null
	var b: Dictionary = BEHAVIORS.get(behavior_name, {})
	if b.is_empty():
		push_warning("EnemyTemplateRegistry: 未知行为 %s" % behavior_name)
		return data
	if b.has("script"):
		data.with_script(b.script)
	for k in b.get("defaults", {}):
		data.param(k, b.defaults[k])
	return data


## 加载数据预设：.tres 资源优先（duplicate 副本，避免污染 load 缓存共享实例），构造链方法兜底
static func _load_preset(data_name: String) -> EnemyData:
	var path := "%s/%s.tres" % [PRESET_DIR, data_name]
	if ResourceLoader.exists(path):
		var loaded := load(path) as EnemyData
		if loaded:
			return loaded.duplicate() as EnemyData
	var data := EnemyData.new()
	if not data.has_method(data_name):
		push_warning("EnemyTemplateRegistry: 未知数据预设 %s" % data_name)
		return null
	data.call(data_name)
	return data


## 行为支持的参数（工作台"建议"按钮用）：行为 defaults 优先 + 反射脚本变量补全
static func suggest_params(behavior_name: String) -> Dictionary:
	var result: Dictionary = {}
	var b: Dictionary = BEHAVIORS.get(behavior_name, {})
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
