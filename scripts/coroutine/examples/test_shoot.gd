extends ShootScript
class_name TestShoot

func _on_run(api: StageAPI):
	for _i in range(5):
		var parent := get_parent()
		var node2d := parent as Node2D
		if not node2d or not is_instance_valid(node2d):
			return
		if def and def.bullet_data:
			api.shoot_circle(def.bullet_data, 12, node2d.global_position)
		await api.seconds(1.5)
