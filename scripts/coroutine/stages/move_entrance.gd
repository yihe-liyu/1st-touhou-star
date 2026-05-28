extends MoveScript
class_name MoveEntrance

@export var target_y: float = 200.0
@export var duration: float = 2.0

var _start: Vector2
var _end_pos: Vector2
var _total_frames: int
var _current_frame: int = 0

func start_moving(api: StageAPI, p_target: Node2D):
	target = p_target
	_start = target.global_position
	_end_pos = Vector2(_start.x, target_y)
	_total_frames = maxi(int(duration * Engine.physics_ticks_per_second), 1)
	_current_frame = 0
	run(_on_step.bind(api))

func _on_step(api: StageAPI) -> Variant:
	if not api.active() or not is_instance_valid(target):
		return false
	_current_frame += 1
	var t := float(_current_frame) / float(_total_frames)
	target.global_position = _start.lerp(_end_pos, t)
	if _current_frame >= _total_frames:
		target.global_position = _end_pos
		return false
	return true
