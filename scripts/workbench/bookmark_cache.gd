## 书签缓存 —— user://bookmarks/stage{id}.json
## 持久化两类书签：
##   auto   ：运行时收集的真实事件时刻（只读，脚本变了自动重收集）
##   manual ：人工打点（可编辑，永远保留）
## script_hash 校验：关卡脚本源码变化 → auto 失效（重收集），manual 保留
extends RefCounted
class_name BookmarkCache


## 缓存格式版本：书签策略变化（如只留整数时刻）时 +1，强制旧缓存重收集
const CACHE_VERSION := 4  # v4: 规范化哈希（键序无关，副本往返稳定）

## 关卡内容哈希：主脚本 + 关卡目录下所有 .gd 文件文本聚合
## （改任何子脚本/敌人/Boss 逻辑都会使书签缓存失效重收集）
static func stage_content_hash(stage: StageData) -> int:
	var h := CACHE_VERSION
	if stage and stage.create_script:
		h = h * 31 + stage.create_script.source_code.hash()
		var stage_dir: String = stage.create_script.resource_path.get_base_dir().get_base_dir()
		h = _hash_dir_files(stage_dir, h)
		# 数据关卡：哈希实际生效的 timeline 数据（user:// 副本优先）
		# 否则改波次数据（工作台保存）不会使缓存失效 → 书签与实际波次不匹配
		if "TIMELINE" in stage.create_script:
			var tl: Resource = stage.create_script.TIMELINE
			var user_p := "user://" + tl.resource_path.trim_prefix("res://")
			if FileAccess.file_exists(user_p):
				tl = load(user_p)
			if tl:
				h = h * 31 + _stable_waves_hash(tl.get("waves"))
	return h


## 波次数据稳定哈希：键排序 + 波次排序 + 稳定字符串表示
## （消除 var_to_str 对字典键序/浮点表示敏感的差异——副本保存/反序列化
##  往返后键序可能变化，导致缓存每次都判"数据已变化"）
static func _stable_waves_hash(waves: Variant) -> int:
	if waves == null:
		return 0
	var parts: Array = []
	for w in waves:
		if w is Dictionary:
			parts.append(_stable_dict_str(w))
		else:
			parts.append(str(w))
	parts.sort()
	var h := 0
	for p in parts:
		h = h * 31 + p.hash()
	return h


static func _stable_dict_str(d: Dictionary) -> String:
	var keys := d.keys()
	keys.sort()
	var parts: Array = []
	for k in keys:
		parts.append("%s=%s" % [str(k), _stable_value_str(d[k])])
	return "|".join(parts)


## 值稳定表示：Vector2/Color 显式格式化（避免默认 str 精度差异）
static func _stable_value_str(v: Variant) -> String:
	if v is Vector2:
		return "V2(%.6f,%.6f)" % [v.x, v.y]
	if v is Vector3:
		return "V3(%.6f,%.6f,%.6f)" % [v.x, v.y, v.z]
	if v is Color:
		return "C(%.6f,%.6f,%.6f,%.6f)" % [v.r, v.g, v.b, v.a]
	if typeof(v) == TYPE_FLOAT:
		return "F%.6f" % v
	if v is Dictionary:
		return _stable_dict_str(v)
	if v is Array:
		var parts: Array = []
		for e in v:
			parts.append(_stable_value_str(e))
		return "[" + ",".join(parts) + "]"
	return str(v)


static func _hash_dir_files(dir_path: String, h: int) -> int:
	var d := DirAccess.open(dir_path)
	if d == null:
		return h
	# 先收集再排序：目录遍历顺序不稳定 → 不排序则哈希每次不同 → 缓存永不命中
	var sub_dirs: Array[String] = []
	var files: Array[String] = []
	d.list_dir_begin()
	var f := d.get_next()
	while f != "":
		if d.current_is_dir():
			sub_dirs.append(f)
		elif f.ends_with(".gd"):
			files.append(f)
		f = d.get_next()
	d.list_dir_end()
	files.sort()
	sub_dirs.sort()
	for fn in files:
		var fa := FileAccess.open(dir_path + "/" + fn, FileAccess.READ)
		if fa:
			h = h * 31 + fa.get_as_text().hash()
			fa.close()
	for sd in sub_dirs:
		h = _hash_dir_files(dir_path + "/" + sd, h)
	return h


static func _path(stage_id: int) -> String:
	return "user://bookmarks/stage%d.json" % stage_id


## 是否有缓存文件（区分"首次"与"数据变化"：首次无文件，变化有但 hash 不匹配）
static func has_cache(stage_id: int) -> bool:
	return FileAccess.file_exists(_path(stage_id))


## 读缓存 → {ok, auto: [{t}], manual: [{t, label}]}
## ok=false 且 manual 非空 = 脚本变了（auto 待重收集，manual 保留）
static func load(stage_id: int, script_hash: int) -> Dictionary:
	var path := _path(stage_id)
	if not FileAccess.file_exists(path):
		return {"ok": false, "auto": [], "manual": []}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {"ok": false, "auto": [], "manual": []}
	var data: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(data) != TYPE_DICTIONARY or data.get("stage_id", -1) != stage_id:
		return {"ok": false, "auto": [], "manual": []}
	if data.get("script_hash", 0) != script_hash:
		# 脚本变了：auto 失效，人工打点保留
		return {"ok": false, "auto": [], "manual": data.get("manual", [])}
	return {
		"ok": true,
		"auto": data.get("auto", []),
		"manual": data.get("manual", []),
	}


static func save(stage_id: int, script_hash: int, auto: Array, manual: Array) -> void:
	DirAccess.make_dir_recursive_absolute("user://bookmarks")
	var f := FileAccess.open(_path(stage_id), FileAccess.WRITE)
	if f == null:
		push_warning("BookmarkCache: 无法写入 " + _path(stage_id))
		return
	f.store_string(JSON.stringify({
		"stage_id": stage_id,
		"script_hash": script_hash,
		"auto": auto,
		"manual": manual,
	}, "\t"))
	f.close()
