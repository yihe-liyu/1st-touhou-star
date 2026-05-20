extends ShootScript
class_name TestShoot

func _on_run(api: StageAPI):
	var pos := get_parent().global_position
	for _i in range(5):
		if def and def.bullet_data:
			api.shoot_circle(def.bullet_data, 12, 200.0, pos)
		await api.seconds(1.5)
