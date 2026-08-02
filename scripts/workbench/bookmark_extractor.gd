## 书签提取器 —— 从关卡脚本源码自动提取 tl.at() 时刻
## 工作台书签不再硬编码：加载任意关卡时扫描其编排脚本，
## 正则提取 `tl.at(X)` 的字面量时刻（循环变量表达式只取基础值）。
extends RefCounted
class_name BookmarkExtractor

## 提取关卡脚本里的时间锚点 → [{t: float, label: String}]（升序、去重）
static func extract_from_script(script: Script) -> Array[Dictionary]:
	var times: Array[float] = []
	if script == null:
		return []
	var source: String = script.source_code
	if source.is_empty():
		return []
	var re := RegEx.new()
	# 匹配 tl.at( 后面的字面量数字（负数/小数；忽略变量表达式）
	re.compile(r"tl\.at\(\s*(-?[0-9]+(?:\.[0-9]+)?)")
	for m in re.search_all(source):
		times.append(float(m.get_string(1)))
	# 升序 + 去重（0.2s 内合并，循环生成的基础时刻）
	times.sort()
	var result: Array[Dictionary] = []
	var last := -INF
	for t in times:
		if t - last < 0.2:
			continue
		last = t
		result.append({"t": t, "label": "t=%.1fs" % t})
	return result
