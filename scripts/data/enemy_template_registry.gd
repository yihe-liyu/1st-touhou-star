## 敌人模板注册表 —— 预设与自定义脚本的统一入口
## 名字 → 模板（复用现有协程脚本 + 构造链 + 默认参数）
## 以后"自定义敌人"= 注册一行 {kind:"script", script, builder, defaults}
class_name EnemyTemplateRegistry
extends RefCounted

const ENEMY01 := preload("res://data/stages/stage01/coroutine_script/enemy01.gd")
const ENEMY02 := preload("res://data/stages/stage01/coroutine_script/enemy02.gd")

## name → {script, builder(EnemyData 构造链函数), defaults(默认参数)}
const TEMPLATES := {
	"red_little": {"script": ENEMY01, "builder": "red_little_fairy", "defaults": {"target_y": 300.0}},
	"red_middle": {"script": ENEMY02, "builder": "red_middle_fairy", "defaults": {"target_pos": Vector2(448, 300)}},
}


## 按模板名构建 EnemyData（脚本 + 外观 + 默认参数）
static func build(name: String) -> EnemyData:
	var t: Dictionary = TEMPLATES.get(name, {})
	if t.is_empty():
		return null
	var data := EnemyData.new()
	data.script(t.script)
	if t.has("builder"):
		data.call(t.builder)
	for k in t.get("defaults", {}):
		data.param(k, t.defaults[k])
	return data


## 模板名列表（工作台下拉框用）
static func names() -> Array:
	var keys := TEMPLATES.keys()
	keys.sort()
	return keys


## 模板支持的参数名（工作台"建议"按钮用，来自模板 defaults）
static func suggest_params(name: String) -> Array:
	var t: Dictionary = TEMPLATES.get(name, {})
	var d: Dictionary = t.get("defaults", {})
	var keys := d.keys()
	keys.sort()
	return keys
