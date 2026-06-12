extends MoveScript
class_name MoveEntrance

## 入场：目标从当前位置平滑移到指定 Y 坐标
@export var target_y: float = 200.0
@export var duration: float = 2.0

var _wait: float = 0.0

func start_moving(api: StageAPI, p_target: Node2D):
	target = p_target
	var end_pos := Vector2(target.global_position.x, target_y)
	var tween := target.create_tween()
	tween.tween_property(target, "global_position", end_pos, duration) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUINT)
	_wait = duration
	run(_on_step.bind(api))

func _on_step(_api: StageAPI) -> Variant:
	return _api.seconds(_wait)
