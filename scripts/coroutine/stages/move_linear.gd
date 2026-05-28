extends MoveScript
class_name MoveLinear

func _on_step(api: StageAPI) -> Variant:
	if not api.active() or not is_instance_valid(target):
		return false
	target.global_position += target.velocity / Engine.physics_ticks_per_second
	target.rotation = target.velocity.angle()
	return true
