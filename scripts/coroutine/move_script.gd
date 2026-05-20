extends CoroutineRunner
class_name MoveScript

var enemy: Enemy

func start_moving(api: StageAPI, p_enemy: Enemy):
	enemy = p_enemy
	run(_on_run.bind(api))

func _on_run(_api: StageAPI):
	pass
