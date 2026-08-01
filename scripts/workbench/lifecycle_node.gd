## 生命周期节点 —— 工作台模型层核心
##
## 每个对象（子弹/激光/敌人/符卡/关卡）都是一个生命周期节点：
##   - 局部时间（从出生起）
##   - 挂在父节点时间线上（anchor = 出生时刻）
##   - 子节点在锚点生成 → 自动嵌套成树
##   - 确定性：simulate_to(t) 从出生重置后推进到 t（RNG 种子一致 → 结果一致）
##
## 纯逻辑模型（不依赖 autoload / 场景树）—— 可在 @tool 编辑器环境运行
class_name LifecycleNode
extends RefCounted

const TICK := 1.0 / 60.0  ## 模拟步长（固定，保证确定性）

var parent: LifecycleNode
var anchor: float = 0.0        ## 父创建本节点时的父局部时间
var local_time: float = 0.0    ## 本节点局部时间（从出生起）
var children: Array[LifecycleNode] = []
var alive: bool = false        ## 生成后 true，死亡后 false
var died_at: float = -1.0      ## 死亡时局部时间（-1 = 未死）

var _spawn_queue: Array = []   # [{t, node}] 按 t 升序


## 世界时间（递归累加所有祖先锚点）—— "时间树以主对象时间线为锚"
func world_time() -> float:
	var t := local_time
	var node: LifecycleNode = self
	while node.parent:
		t += node.anchor
		node = node.parent
	return t


## 挂到父节点：anchor = 父当前局部时间
func spawn_under(p_parent: LifecycleNode) -> void:
	spawn_under_at(p_parent, p_parent.local_time)


## 挂到父节点（精确锚点）：anchor = 指定时刻（生成计划用）
func spawn_under_at(p_parent: LifecycleNode, p_anchor: float) -> void:
	parent = p_parent
	anchor = p_anchor
	alive = true
	p_parent.children.append(self)
	_spawn_queue = _spawn_plan().duplicate()  # 副本！原计划数组不被消耗
	_spawn_queue.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.t < b.t)
	_on_spawned()


## 确定性重放：重置后推进到局部时间 t（拖动时间轴/跳转用）
func simulate_to(t: float) -> void:
	reset_state()
	advance_to(t)


## 增量推进（不重置）—— 播放模式用；也是重放的内部实现
## 与重放同一确定性函数 → 增量结果 = 重放结果（逐帧播放等价拖动）
func advance_to(t: float) -> void:
	while local_time < t and alive:
		var dt := minf(TICK, t - local_time)
		_tick(dt)
		local_time += dt
		_process_spawns()
		_sync_children()
		_check_death()


## 重置到出生时刻（确定性起点）
func reset_state() -> void:
	local_time = 0.0
	alive = true
	died_at = -1.0
	children.clear()
	_spawn_queue = _spawn_plan().duplicate()  # 副本！重放多次不消耗原计划
	_spawn_queue.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.t < b.t)
	_on_reset()


## 生命周期总长（死亡时刻；未死 = 当前模拟到的局部时间）
func duration() -> float:
	return died_at if died_at >= 0.0 else local_time


## 树中所有活动节点（含自己，DFS）—— 预览画布用
## 注意：不可用默认数组参数（GDScript 默认数组是静态共享的 → 无限膨胀 OOM！）
func collect_alive() -> Array:
	var result: Array = []
	_collect_alive(result)
	return result


func _collect_alive(result: Array) -> void:
	if alive:
		result.append(self)
	for child in children:
		child._collect_alive(result)


# ── 子类钩子（覆写）──

func _on_spawned() -> void: pass
func _on_reset() -> void: pass
func _on_died() -> void: pass
## 每 tick 行为（dt 固定步长）
func _tick(_dt: float) -> void: pass
## 生成计划：返回 [{t: 局部时刻, node: 子节点实例}]
func _spawn_plan() -> Array: return []
## 死亡条件：局部时间达到返回 true
func _should_die() -> bool: return false
## 行为事件（编排树/时间线展示）：返回 [{t: 局部时刻, label: 描述}]
func _behavior_events() -> Array: return []
## 是否实体（子弹等运行时个体；编排树不显示实体）
func is_entity() -> bool: return false


# ── 内部 ──

func _process_spawns() -> void:
	while _spawn_queue.size() > 0 and _spawn_queue[0].t <= local_time + 0.0001:
		var plan: Dictionary = _spawn_queue.pop_front()
		var node: LifecycleNode = plan.node
		# 生成计划是唯一来源：重置后必须重新生成（不检查 alive，
		# 否则上次模拟存活的实例会被跳过 —— 导致二次 simulate 子树丢失）
		if node == null:
			continue
		node.spawn_under_at(self, plan.t)  # 精确锚点 = 计划时刻


## 同步子节点：子局部时间 = 父当前时间 - 子锚点（递归全树联动）
## 用 advance_to（增量）—— 不重置不重建，逐帧播放高效
func _sync_children() -> void:
	for child in children:
		if child.alive:
			child.advance_to(local_time - child.anchor)


func _check_death() -> void:
	if alive and _should_die():
		alive = false
		died_at = local_time
		_on_died()
