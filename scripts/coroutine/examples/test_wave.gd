extends StageScript
class_name TestLevel

const ENEMY_DATA = preload("res://data/enemy_data/test_enemy_data.tres")
const BG_GROUND = preload("res://assets/Textures/background/stage01/st01a.png")
const BG_LAYER = preload("res://assets/Textures/background/stage01/st01b.png")

func _on_run(api: StageAPI):
	api.bg_set_fog(Color(0.49, 0.42, 0.67, 1))
	api.bg_set_ground(BG_GROUND, Vector2(0, -0.2), 20.0, 0.03, Color(0.3, 0.5, 1.0, 0.0), Color.WHITE)
	api.bg_add_layer(BG_LAYER, Vector2(0, -0.05), 10.0, 0.5, Color.WHITE)

	api.spawn_enemy(ENEMY_DATA, Vector2(640, -50))
	
	api.bg_tween_camera_rotation_degrees(Vector3(-8, 0, 0), 40.0)

	await api.seconds(3.0)

	api.spawn_enemy(ENEMY_DATA, Vector2(300, -50))

	await api.seconds(3.0)
