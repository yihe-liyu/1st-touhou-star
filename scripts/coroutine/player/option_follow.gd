extends MoveScript
class_name OptionFollow

var leader: Node2D
var offset: Vector2

func _on_run(api: StageAPI):
	while api._active() and is_instance_valid(leader) and is_instance_valid(target):
		var goal := leader.global_position + offset
		target.global_position = target.global_position.lerp(goal, 0.2)
		await api.frames(1)
