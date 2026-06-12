extends MoveScript
class_name MoveStage1Enemy1
## Stage 1 敌人 1 移动脚本 — 入场 + 左右巡逻
##
## 生命周期：
##   1. 入场：从起始位置滑到 patrol_y（EASE_OUT, QUINT）
##   2. 巡逻：在 [patrol_x ± range] 间交替摆荡（EASE_IN_OUT, SINE）
##
## 使用：
##   var move := MoveStage1Enemy1.new()
##   add_child(move)
##   move.start_moving(api, enemy_node)

## 入场目标 Y 坐标
@export var entrance_y: float = 200.0

## 入场动画时间（秒）
@export var entrance_duration: float = 2.0

## 巡逻 X 中心
@export var patrol_x: float = 320.0

## 左右摆幅（像素）
@export var range: float = 100.0

## 单程时间（秒）
@export var period: float = 1.5

enum Phase { ENTRANCE, PATROL }
var _phase: Phase = Phase.ENTRANCE
var _going_right: bool = true
var _tween: Tween


func start_moving(api: StageAPI, p_target: Node2D):
	target = p_target

	# 通知动画：开始移动
	var visual := target.get_node_or_null("EnemyVisual") as EnemyVisual
	if visual:
		visual.set_moving(true)

	# ── 入场：滑到 (patrol_x, entrance_y) ──
	var end_pos := Vector2(patrol_x, entrance_y)
	_tween = target.create_tween()
	_tween.tween_property(target, "global_position", end_pos, entrance_duration) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUINT)

	_phase = Phase.ENTRANCE
	run(_on_step.bind(api))


func _on_step(api: StageAPI) -> Variant:
	if not api.active() or not is_instance_valid(target):
		return false

	match _phase:
		Phase.ENTRANCE:
			_phase = Phase.PATROL
			_going_right = true
			return api.seconds(entrance_duration)

		Phase.PATROL:
			_going_right = not _going_right
			var dest := patrol_x + range if _going_right else patrol_x - range

			# 翻向
			if target is AnimatedSprite2D or target.has_method("set_moving"):
				var sprite := target.get_node_or_null("EnemyVisual") as AnimatedSprite2D
				if not sprite:
					sprite = target as AnimatedSprite2D
				if sprite:
					sprite.flip_h = not _going_right

			_tween = target.create_tween()
			_tween.tween_property(target, "global_position:x", dest, period) \
				.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

			return api.seconds(period)

	return false


func stop():
	if _tween and _tween.is_valid():
		_tween.kill()
	var visual := target.get_node_or_null("EnemyVisual") as EnemyVisual if is_instance_valid(target) else null
	if visual:
		visual.set_moving(false)
	super.stop()
