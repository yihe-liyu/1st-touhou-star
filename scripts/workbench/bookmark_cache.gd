## 书签缓存 —— user://bookmarks/stage{id}.json
## 持久化两类书签：
##   auto   ：运行时收集的真实事件时刻（只读，脚本变了自动重收集）
##   manual ：人工打点（可编辑，永远保留）
## script_hash 校验：关卡脚本源码变化 → auto 失效（重收集），manual 保留
extends RefCounted
class_name BookmarkCache


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
