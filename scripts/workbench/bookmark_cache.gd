## 书签缓存 —— user://bookmarks/stage{id}.json
## 持久化两类书签：
##   auto   ：运行时收集的真实事件时刻（只读，脚本变了自动重收集）
##   manual ：人工打点（可编辑，永远保留）
## script_hash 校验：关卡脚本源码变化 → auto 失效（重收集），manual 保留
extends RefCounted
class_name BookmarkCache


## 缓存格式版本：书签策略变化（如只留整数时刻）时 +1，强制旧缓存重收集
const CACHE_VERSION := 2

## 关卡内容哈希：主脚本 + 关卡目录下所有 .gd 文件文本聚合
## （改任何子脚本/敌人/Boss 逻辑都会使书签缓存失效重收集）
static func stage_content_hash(stage: StageData) -> int:
	var h := CACHE_VERSION
	if stage and stage.create_script:
		h = h * 31 + stage.create_script.source_code.hash()
		var stage_dir: String = stage.create_script.resource_path.get_base_dir().get_base_dir()
		h = _hash_dir_files(stage_dir, h)
	return h


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
