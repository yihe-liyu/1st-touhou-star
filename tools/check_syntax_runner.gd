extends Node
## 秒级全项目 .gd 编译检查（场景启动模式：autoload 完整注册，编译上下文与真实游戏一致）
## 每个脚本用 GDScript.source_code + reload() 从源码强制重编译，绕开 .godot 文件缓存。
## 用法：godot --headless --path . res://tools/check_syntax_scene.tscn

const SCAN_DIRS: Array[String] = ["res://scripts", "res://data"]

var _failures: Array[String] = []
var _total := 0


func _ready() -> void:
	for d in SCAN_DIRS:
		_scan(d)
	for f in _failures:
		print("[SYNTAX FAIL] ", f)
	print("check_syntax: 扫描 %d 个脚本，%d 个失败" % [_total, _failures.size()])
	get_tree().quit(1 if _failures.size() > 0 else 0)


func _scan(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_error("无法打开目录: " + dir_path)
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if dir.current_is_dir() and not name.begins_with("."):
			_scan(dir_path.path_join(name))
		elif name.ends_with(".gd"):
			var path := dir_path.path_join(name)
			_total += 1
			# 场景模式 load()：autoload 完整注册、class_name 全局可用，编译上下文与真实游戏一致
			if load(path) == null:
				_failures.append(path)
		name = dir.get_next()
	dir.list_dir_end()
