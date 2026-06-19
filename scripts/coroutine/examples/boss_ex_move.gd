# boss_ex_move.gd
extends MoveScript
## 示例：boss 左右慢速摇摆

const AMPLITUDE := 120.0

var _center_x: float
var _t: float = 0.0

func start_moving(p_ctx: StageContext, p_target: Node2D) -> void:
	ctx = p_ctx
	target = p_target
	_center_x = target.global_position.x
	run(_on_step.bind(ctx))

func _on_step(_ctx: StageContext) -> Variant:
	_t += 0.015
	target.global_position.x = _center_x + sin(_t) * AMPLITUDE
	return true
