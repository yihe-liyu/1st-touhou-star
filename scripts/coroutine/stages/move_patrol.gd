extends MoveScript
class_name MovePatrol
## 左右巡逻 — 目标在 [start_x - range, start_x + range] 间交替摆荡
##
## 使用：
##   patrol.start_moving(api, target_node)
##
## 原理：
##   每周期 Tween 到对侧极端, 协程等 period 秒后翻向。

## 左右摆动幅度（像素）
@export var range: float = 100.0

## 单程时间（秒）
@export var period: float = 1.5

var _start_x: float
var _going_right: bool = true


func start_moving(api: StageAPI, p_target: Node2D):
	target = p_target
	_start_x = target.global_position.x
	_going_right = true
	run(_on_step.bind(api))


func _on_step(api: StageAPI) -> Variant:
	if not api.active() or not is_instance_valid(target):
		return false

	_going_right = not _going_right
	var dest := _start_x + range if _going_right else _start_x - range

	var tween := target.create_tween()
	tween.tween_property(target, "global_position:x", dest, period) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

	return api.seconds(period)
