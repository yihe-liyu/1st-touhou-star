extends CoroutineRunner
class_name BulletMoveScript

var bullet: Bullet

func start_moving(api: StageAPI, p_bullet: Bullet):
	bullet = p_bullet
	run(_on_run.bind(api))

func _on_run(_api: StageAPI):
	pass
