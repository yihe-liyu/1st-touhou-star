class_name EnemyTemplateRegistry
extends RefCounted
## 敌人数据/行为注册表 —— 自由组合
##
##   数据层：data/enemy_presets/*.tres（EnemyData 预设：外观/血量/判定/掉落）
##   行为层：BEHAVIORS（移动+发弹脚本，可复用）
##   组合：build_from(数据名, 行为名) —— 同数据换行为 / 同行为换数据
## 创作方式：新行为 = 注册 BEHAVIORS 一行；新数据 = 复制 .tres。

const ENEMY_DATA_SCRIPT := preload("res://scripts/data/enemy_data.gd")
const PRESET_DIR := "res://data/enemy_presets"

## 行为层：{行为名: {script_path, defaults(脚本参数默认)}}
## script_path 运行时 load + 缓存（不用 preload）：工作台「脚本」页签保存后
## reload_behavior() 热重载立即生效，无需重启；游戏本体行为不变
const BEHAVIORS := {
	"aim_scatter": {"script_path": "res://data/stages/stage01/coroutine_script/enemy01.gd", "defaults": {"target_y": 300.0}},
	"middle_sweep": {"script_path": "res://data/stages/stage01/coroutine_script/enemy02.gd", "defaults": {"target_pos": Vector2(448, 300)}},
	"sway_aim": {"script_path": "res://scripts/data/enemy_templates/sway_fairy.gd", "defaults": {"target_y": 260.0, "sway": 80.0, "bullet_n": 5, "fire_interval": 0.6}},
}

## 运行时脚本缓存（path → Script）；reload_behavior 后失效重载
static var _script_cache: Dictionary = {}

## 行为脚本（运行时 load + 缓存；编译失败时重试 load）
static func behavior_script(name: String) -> Script:
	var b: Dictionary = BEHAVIORS.get(name, {})
	if b.is_empty() or not b.has("script_path"):
		return null
	var p: String = b["script_path"]
	if not _script_cache.has(p):
		_script_cache[p] = load(p)
	return _script_cache[p]

## 行为脚本路径（工作台脚本编辑器显示/保存用）
static func behavior_path(name: String) -> String:
	var b: Dictionary = BEHAVIORS.get(name, {})
	return str(b.get("script_path", ""))

## 热重载行为脚本（工作台保存后调用）
## CACHE_MODE_IGNORE：绕过脚本编译缓存强制重编译（对象身份不变但字节码更新）
## 注意：Script.reload() 在非编辑器运行时是 no-op（err=0 不做事）；remove_from_cache 不存在；
## CACHE_MODE_REPLACE 对 GDScript 也不生效——实测只有 IGNORE 会强制重编译。
## 编译失败：load 返回 null，旧缓存保留 → 返回 false（工作台提示，不炸）
static func reload_behavior(name: String) -> bool:
	var b: Dictionary = BEHAVIORS.get(name, {})
	if b.is_empty() or not b.has("script_path"):
		return false
	var p: String = b["script_path"]
	var s: Script = ResourceLoader.load(p, "", ResourceLoader.CACHE_MODE_IGNORE)
	if s == null or not (s is Script):
		return false
	_script_cache[p] = s
	return true

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
	var script: Script = behavior_script(behavior_name)
	if script:
		data.with_script(script)
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
	var script: Script = behavior_script(behavior_name)
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
