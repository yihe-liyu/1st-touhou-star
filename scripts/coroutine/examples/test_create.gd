extends CreateScript
class_name TestShoot

const BULLET_DATA = preload("res://data/bullet_data/test_enemy_bullet.tres")

func _on_run(api: StageAPI):
	for _i in range(8):
		var parent := get_parent()
		var node2d := parent as Node2D
		if not node2d or not is_instance_valid(node2d):
			return
		api.shoot_circle(BULLET_DATA, 24, node2d.global_position)
		await api.seconds(1)
