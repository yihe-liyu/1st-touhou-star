extends MoveScript
class_name OptionFollow

var leader: Node2D
var offset: Vector2

## 追赶速度（单位：1/秒），值越大跟随越紧
const FOLLOW_SPEED: float = 13.39

var _lerp_factor: float

func start_moving(api: StageAPI, p_target: Node2D, p_ctx = null):
	ctx = p_ctx
	target = p_target
	var delta := 1.0 / Engine.physics_ticks_per_second
	_lerp_factor = 1.0 - exp(-FOLLOW_SPEED * delta)
	run(_on_step.bind(api))

func _on_step(api: StageAPI) -> Variant:
	if not api.active() or not is_instance_valid(leader) or not is_instance_valid(target):
		return false
	var goal := leader.global_position + offset
	target.global_position = target.global_position.lerp(goal, _lerp_factor)
	return true
