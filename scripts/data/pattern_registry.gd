class_name PatternRegistry
extends RefCounted
## 弹幕模式注册表 —— 内置标准件 + 自定义脚本的统一入口
## 名字 → 执行方式；工作台下拉框/PatternDriver 均通过这里解析
##
## 内置标准件（纯数据执行，无需写代码）：ring / aim / fan
## 自定义模式 = 写一个 extends PatternScript 的 .gd → register_script 注册 → 同预设使用
##
## 参数约定（params）：数组 = 按难度取 [Easy, Normal, Hard, Lunatic]；标量 = 全难度一致

## 内置标准件列表
const BUILTINS := ["ring", "aim", "fan"]

## 内置自定义脚本（编译期注册）
const SCRIPTS := {
	"spiral": preload("res://scripts/data/patterns/spiral.gd"),
}

## 运行时注册（测试/编辑器热重载用）：注册后 names()/is_script()/instantiate 立即可用
static var _extra_scripts: Dictionary = {}


static func register_script(name: String, script: Script) -> void:
	_extra_scripts[name] = script


static func unregister_script(name: String) -> void:
	_extra_scripts.erase(name)


## 模式名列表（工作台下拉框用）
static func names() -> Array:
	var n := BUILTINS.duplicate()
	for k in _all_scripts():
		n.append(k)
	n.sort()
	return n


## 常用参数建议（工作台"添加参数"弹窗的快捷按钮）
## 返回 Dictionary：键 → 默认值；内置模式写死，脚本模式自动识别
static func suggest_params(pattern_name: String) -> Dictionary:
	match pattern_name:
		"ring":
			return {"n": 24, "speed": 300.0, "aim": false, "random_start": false}
		"aim":
			return {"n": 5, "spread": 30.0, "speed": 300.0}
		"fan":
			return {"n": 5, "spread": 60.0, "speed": 300.0}
	# 脚本模式：优先作者 params_schema() 声明，否则反射脚本变量
	if is_script(pattern_name):
		var inst := instantiate_script(pattern_name)
		if inst:
			if inst.has_method("params_schema"):
				var schema: Dictionary = inst.params_schema()
				if not schema.is_empty():
					return schema
			var result := _reflect_params(inst)
			if not result.is_empty():
				return result
	return {"n": 24, "speed": 300.0}


## 反射脚本实例的非私有、非基类运行时变量（自动识别自定义脚本参数）
static func _reflect_params(inst: CoroutineScript) -> Dictionary:
	var result: Dictionary = {}
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


static func has(name: String) -> bool:
	return BUILTINS.has(name) or _all_scripts().has(name)


static func is_script(name: String) -> bool:
	return _all_scripts().has(name)


## 实例化自定义模式脚本（脚本模式专用）
static func instantiate_script(name: String) -> CoroutineScript:
	if not is_script(name):
		return null
	var script: Script = _all_scripts()[name]
	return script.new() as CoroutineScript


## 执行一次内置模式发射（脚本模式不走这里，由 PatternScript 自己驱动）
static func execute(ctx: StageContext, pattern_name: String, bullet: BulletData,
		at: Vector2, base_dir: Vector2, params: Dictionary) -> void:
	match pattern_name:
		"ring":
			_exec_ring(ctx, bullet, at, base_dir, params)
		"aim":
			_exec_aim(ctx, bullet, at, base_dir, params)
		"fan":
			_exec_fan(ctx, bullet, at, base_dir, params)


## 难度数组取值：数组按当前难度取，标量原样返回
static func diff_pick(v: Variant) -> Variant:
	if v is Array:
		var idx := clampi(GameState.selected_difficulty, 0, v.size() - 1)
		return v[idx]
	return v


# ═══ 内置模式 ═══

## 全圈 n 颗。aim=true 对准玩家；false 用 base_dir 作起始角（配合 rotate_step 转环）
static func _exec_ring(ctx: StageContext, bullet: BulletData, at: Vector2, base_dir: Vector2, params: Dictionary) -> void:
	var n := int(diff_pick(params.get("n", 24)))
	if params.has("speed"):
		bullet.speed(float(diff_pick(params.get("speed"))))
	var base := base_dir
	if bool(diff_pick(params.get("aim", false))):
		var player := ctx.player.get_player()
		if player:
			base = (player.global_position - at).normalized()
	ctx.bullets.shoot_spread(bullet, maxi(n, 1), TAU, base, at)


## 自机狙扇形（n 颗、spread 度、朝向玩家）
static func _exec_aim(ctx: StageContext, bullet: BulletData, at: Vector2, _base_dir: Vector2, params: Dictionary) -> void:
	var n := int(diff_pick(params.get("n", 5)))
	var spread_deg := float(diff_pick(params.get("spread", 30)))
	if params.has("speed"):
		bullet.speed(float(diff_pick(params.get("speed"))))
	var player := ctx.player.get_player()
	var base := Vector2.DOWN
	if player:
		base = (player.global_position - at).normalized()
	ctx.bullets.shoot_spread(bullet, maxi(n, 1), deg_to_rad(spread_deg), base, at)


## 固定方向扇形（base_dir 为中间方向）
static func _exec_fan(ctx: StageContext, bullet: BulletData, at: Vector2, base_dir: Vector2, params: Dictionary) -> void:
	var n := int(diff_pick(params.get("n", 5)))
	var spread_deg := float(diff_pick(params.get("spread", 60)))
	if params.has("speed"):
		bullet.speed(float(diff_pick(params.get("speed"))))
	ctx.bullets.shoot_spread(bullet, maxi(n, 1), deg_to_rad(spread_deg), base_dir, at)


static func _all_scripts() -> Dictionary:
	var all := SCRIPTS.duplicate()
	for k in _extra_scripts:
		all[k] = _extra_scripts[k]
	return all
