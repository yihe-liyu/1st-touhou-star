extends MoveScript
class_name MoveEntrance

@export var target_y: float = 200.0
@export var duration: float = 2.0

func _on_run(api: StageAPI):
	var start := enemy.global_position
	var target := Vector2(start.x, target_y)

	var total_frames := maxi(int(duration * 60.0), 1)
	for i in total_frames:
		var t := float(i + 1) / float(total_frames)
		enemy.global_position = start.lerp(target, t)
		await api.frames(1)
	enemy.global_position = target
