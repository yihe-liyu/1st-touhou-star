## 激光引擎（新）—— 池 + 生成 + 每帧推进
## 替换旧 LaserSystem（第 3 步接入渲染后正式替换）
class_name LaserEngine
extends RefCounted

const POOL_SIZE := 64

var _pool: Array[LaserBeam] = []
var _active: Array[LaserBeam] = []
var _parent: Node
var _pool_index: int = 0


func setup(p_parent: Node) -> void:
	_parent = p_parent
	for i in POOL_SIZE:
		var beam := LaserBeam.new()
		beam.name = "LaserBeam_%d" % i
		beam.process_mode = Node.PROCESS_MODE_DISABLED
		beam.visible = false
		_parent.add_child(beam)
		_pool.append(beam)


## 取一条可用的光束（全活时踢最老）
func _acquire() -> LaserBeam:
	for i in POOL_SIZE:
		var idx := (_pool_index + i) % POOL_SIZE
		if _pool[idx].phase == LaserBeam.Phase.DEAD:
			_pool_index = (idx + 1) % POOL_SIZE
			return _pool[idx]
	var reuse: LaserBeam = _active.pop_front()
	return reuse


## 统一生成入口：骨架 + 颜色（形态/参数在 beam 上配置）
func spawn(skeleton: LaserSkeleton, color: Color) -> LaserBeam:
	var beam := _acquire()
	if beam == null:
		return null
	beam.spawn(skeleton, color)
	_active.append(beam)
	return beam


## 便捷：直线激光
func spawn_line(a: Vector2, b: Vector2, color: Color) -> LaserBeam:
	var sk := LaserSkeleton.new()
	sk.from_line(a, b)
	return spawn(sk, color)


## 便捷：曲线激光（Curve2D，均匀采样）
func spawn_curve(curve: Curve2D, color: Color, seg_len: float = 32.0) -> LaserBeam:
	var sk := LaserSkeleton.new()
	sk.from_curve(curve, seg_len)
	return spawn(sk, color)


## 每帧推进所有活动激光（回收 DEAD）
func step(_delta: float) -> void:
	for i in range(_active.size() - 1, -1, -1):
		if _active[i].phase == LaserBeam.Phase.DEAD:
			_active[i]._reset()
			_active.remove_at(i)


func clear() -> void:
	for beam in _active:
		beam._reset()
	_active.clear()


func get_active() -> Array[LaserBeam]:
	return _active
