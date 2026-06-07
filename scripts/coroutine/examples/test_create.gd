extends CreateScript
class_name TestShoot

const BULLET_DATA = preload("res://data/bullet_data/test_enemy_bullet.tres")

var _i: int = 0

func _on_step(api: StageAPI) -> Variant:
	if _i >= 4000000:
		return false
	var parent := get_parent()
	var node2d := parent as Node2D
	if not node2d or not is_instance_valid(node2d):
		return false
	api.shoot_spread(BULLET_DATA, 8, TAU, Vector2.RIGHT.rotated(deg_to_rad(_i * 2)), node2d.global_position)
	AudioManager.play_sfx(preload("res://assets/Sound/tan00.wav"), -8.0)
	_i += 1
	return api.seconds(0.2)
