extends MoveScript
class_name MoveLinear

func _on_step(_ctx: StageContext) -> Variant:
	if not ctx.active() or not is_instance_valid(target):
		return false
	target.global_position += target.velocity / Engine.physics_ticks_per_second
	target.rotation = target.velocity.angle()
	return true
