extends CoroutineScript
class_name OptionFollow

var leader: Node2D
var offset: Vector2

## 追赶速度（单位：1/秒），值越大跟随越紧
const FOLLOW_SPEED: float = 13.39

var _lerp_factor: float

func start(p_ctx: StageContext, p_target: Node2D = null):
	ctx = p_ctx
	if p_target:
		target = p_target
	var delta := get_dt()
	_lerp_factor = 1.0 - exp(-FOLLOW_SPEED * delta)
	super.start(ctx, target)

func _tick(_ctx: StageContext) -> Variant:
	if not ctx.active() or not is_instance_valid(leader) or not is_instance_valid(target):
		return false
	var goal := leader.global_position + offset
	target.global_position = target.global_position.lerp(goal, _lerp_factor)
	return true
