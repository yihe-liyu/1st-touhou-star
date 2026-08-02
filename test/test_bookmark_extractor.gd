extends GutTest
## 书签提取器测试：从关卡脚本源码提取 tl.at 时刻

const Extractor = preload("res://scripts/workbench/bookmark_extractor.gd")


func test_extracts_tl_at_literals() -> void:
	var script := GDScript.new()
	script.source_code = """
func start(ctx):
	var tl := start_timeline()
	tl.at(0.0).play_bgm(bgm)
	tl.at(1.0 + i * 0.1).do(func(): pass)  # 循环基础值
	tl.at(7.0).do(func(): pass)
	tl.at(35.0).phase(func(): return null, phase)
	tl.wait(2.0).do(func(): pass)  # 不应被提取
	"""
	var bm := Extractor.extract_from_script(script)
	var ts: Array = []
	for b in bm:
		ts.append(b.t)
	assert_eq(ts, [0.0, 1.0, 7.0, 35.0], "应提取字面量时刻且升序去重")


func test_empty_on_null_script() -> void:
	assert_eq(Extractor.extract_from_script(null), [], "null 脚本返回空")


func test_dedup_close_times() -> void:
	var script := GDScript.new()
	script.source_code = "func s():\n\ttl.at(5.0).do(f)\n\ttl.at(5.05).do(f)\n"
	var bm := Extractor.extract_from_script(script)
	assert_eq(bm.size(), 1, "0.2s 内合并")
