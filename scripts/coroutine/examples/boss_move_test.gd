# boss_move_test.gd
extends MoveScript

const AMPLITUDE := 150.0
const FREQ := 0.02

var _center_x: float
var _t: float = 0.0


func start_moving(api: StageAPI, p_target: Node2D) -> void:
	target = p_target
	_center_x = target.global_position.x
	run(_on_step.bind(api))

func _on_step(_api: StageAPI) -> Variant:
	_t += FREQ
	target.global_position.x = _center_x + sin(_t) * AMPLITUDE
	return true
