## 激光光束 —— 状态机驱动骨架生长/持续/收缩/淡出
## 阶段：GROW → SUSTAIN → CONTRACT | FADE → DEAD
## 判定与渲染共用骨架采样；head/tail 未变时 _dirty=false（静止零重建）
class_name LaserBeam
extends Node2D

enum Phase { GROW, SUSTAIN, CONTRACT, FADE, DEAD }

# ── 配置（spawn 前设置，默认值合理）──
var laser_color: Color = Color(1.0, 0.2, 0.1)
var core_width: float = 16.0        ## 视觉光柱宽度
var hitbox_width: float = 6.0       ## 命中判定宽度（细线！）
var graze_width: float = 22.0       ## 擦弹判定宽度
var grow_speed: float = 600.0       ## 生长/收缩速度（px/s）
var tail_distance: float = 300.0    ## 生长型：尾部滞后距离
var max_lifetime: float = 8.0       ## 持续时长（0 = 无限）
var grow_on_spawn: bool = true      ## true=生长型；false=瞬间全开（固定/直线型）

# ── 运行时 ──
var skeleton: LaserSkeleton
var phase: Phase = Phase.DEAD
var age: float = 0.0
var head_dist: float = 0.0
var tail_dist: float = 0.0
var _dirty: bool = true             ## 骨架可见段是否变化（渲染层据此重建）
var _fade_age: float = 0.0


## 初始化（池复用入口）：绑定骨架 + 重置状态
func spawn(p_skeleton: LaserSkeleton, p_color: Color) -> void:
	skeleton = p_skeleton
	laser_color = p_color
	age = 0.0
	_fade_age = 0.0
	_dirty = true
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
	if grow_on_spawn and grow_speed > 0.0:
		phase = Phase.GROW
		head_dist = 0.0
		tail_dist = 0.0
	else:
		phase = Phase.SUSTAIN  # 瞬间全开：可见段 = 全长
		head_dist = skeleton.total_length
		tail_dist = 0.0


func _physics_process(delta: float) -> void:
	if phase == Phase.DEAD:
		return
	var old_head := head_dist
	var old_tail := tail_dist
	age += delta
	match phase:
		Phase.GROW:
			head_dist = minf(head_dist + grow_speed * delta, skeleton.total_length)
			# 尾部滞后：距离头部 tail_distance（不短于 0）
			tail_dist = maxf(tail_dist, head_dist - tail_distance)
			if head_dist >= skeleton.total_length:
				phase = Phase.SUSTAIN
		Phase.SUSTAIN:
			if max_lifetime > 0.0 and age >= max_lifetime:
				# 生长型收缩消失；固定型淡出
				phase = Phase.CONTRACT if grow_on_spawn else Phase.FADE
		Phase.CONTRACT:
			# 尾部追上头部 → 消失
			tail_dist = minf(tail_dist + grow_speed * delta, head_dist)
			if tail_dist >= head_dist - 0.5:
				phase = Phase.DEAD
		Phase.FADE:
			_fade_age += delta
			if _fade_age >= 0.15:
				phase = Phase.DEAD
	_dirty = old_head != head_dist or old_tail != tail_dist
	if phase == Phase.DEAD:
		visible = false
		process_mode = Node.PROCESS_MODE_DISABLED


# ── 判定（点到骨架折线段距离）──

## 可见骨架采样（渲染与判定共用）
func visible_points(count: int) -> PackedVector2Array:
	return skeleton.sample_range(tail_dist, head_dist, count)


## 玩家位置到激光的最小距离
func distance_to(pos: Vector2, count: int = 24) -> float:
	if phase == Phase.DEAD:
		return INF
	if head_dist - tail_dist < 1.0:
		return pos.distance_to(skeleton.sample_at(tail_dist))
	var pts := visible_points(count)
	var best := INF
	for i in range(pts.size() - 1):
		best = minf(best, _dist_to_segment(pos, pts[i], pts[i + 1]))
	return best


## 命中（细判定）
func is_hitting(pos: Vector2) -> bool:
	return distance_to(pos) <= hitbox_width


## 擦弹（宽判定）
func is_grazing(pos: Vector2, graze_radius: float) -> bool:
	return distance_to(pos, 16) <= graze_width + graze_radius


## 池回收：彻底复位（渲染层第 3 步加清理）
func _reset() -> void:
	phase = Phase.DEAD
	skeleton = null
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED


func _dist_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var ap := p - a
	var len_sq := ab.length_squared()
	if len_sq < 0.0001:
		return p.distance_to(a)
	var t := clampf(ap.dot(ab) / len_sq, 0.0, 1.0)
	return p.distance_to(a + ab * t)
