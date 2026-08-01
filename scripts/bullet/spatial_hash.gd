## 空间哈希 —— 网格分区，把 O(n×m) 碰撞降到 O(n+k)
## 每帧重建：clear() + insert(目标)，查询时只取 pos 周围格子内的候选
class_name SpatialHash
extends RefCounted

const CELL: float = 64.0  ## 格子边长（px）；查询半径决定扫描格数

var _grid: Dictionary = {}  # Vector2i → Array[Node2D]


func clear() -> void:
	_grid.clear()


func _key(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / CELL), floori(pos.y / CELL))


## 登记一个目标（用其 global_position 入格）
func insert(node: Node2D) -> void:
	var k := _key(node.global_position)
	var arr: Variant = _grid.get(k)
	if arr == null:
		arr = []
		_grid[k] = arr
	arr.append(node)


## 查询 pos 周围 radius 范围内的所有候选（跨格安全；距离过滤由调用方做）
func query(pos: Vector2, radius: float) -> Array:
	var min_k := _key(pos - Vector2(radius, radius))
	var max_k := _key(pos + Vector2(radius, radius))
	var result: Array = []
	for x in range(min_k.x, max_k.x + 1):
		for y in range(min_k.y, max_k.y + 1):
			var arr: Variant = _grid.get(Vector2i(x, y))
			if arr is Array:
				result.append_array(arr)
	return result
