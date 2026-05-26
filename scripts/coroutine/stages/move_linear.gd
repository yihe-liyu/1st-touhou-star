extends MoveScript
class_name MoveLinear

func _on_run(api: StageAPI):
	while api.active() and is_instance_valid(target):
		target.global_position += target.velocity / Engine.physics_ticks_per_second
		target.rotation = target.velocity.angle()
		await api.frames(1)
