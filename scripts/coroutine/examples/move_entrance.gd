extends MoveScript
class_name MoveEntrance

@export var target_y: float = 200.0
@export var duration: float = 2.0

func _on_run(api: StageAPI):
	var start := target.global_position
	var end_pos := Vector2(start.x, target_y)

	var total_frames := maxi(int(duration * 60.0), 1)
	for i in total_frames:
		var t := float(i + 1) / float(total_frames)
		target.global_position = start.lerp(end_pos, t)
		await api.frames(1)
	target.global_position = end_pos
