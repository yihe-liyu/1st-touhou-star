extends StageScript
class_name TestLevel

const ENEMY_DATA = preload("res://data/enemy_data/test_enemy_data.tres")
const BG_GROUND = preload("res://assets/Textures/background/stage01/st01a.png")
const BG_LAYER = preload("res://assets/Textures/background/stage01/st01b.png")

func _on_run(api: StageAPI):
	api.bg_set_fog(Color(0.539, 0.589, 0.859, 1.0), 3.0, 0.5, 3.0, 30.0, Color(0.055, 0.0, 0.545, 1.0))
	api.bg_set_ground(BG_GROUND, Vector2(0, -0.2), 20.0, 0.03, Color(0.3, 0.5, 1.0, 0.0), Color.WHITE)
	api.bg_add_layer(BG_LAYER, Vector2(0, -0.05), 10.0, 0.5, Color.WHITE)
	api.bg_save_snapshot("stage_start")

	api.spawn_enemy(ENEMY_DATA, Vector2(640, -50))

	api.bg_tween("camera.rotation", Vector3(-8, 2, 0), 3.0, "smooth")
	api.bg_tween("fog.density", 2.0, 3.0, "smooth")

	await api.seconds(3.0)

	api.spawn_enemy(ENEMY_DATA, Vector2(300, -50))

	await api.seconds(3.0)

	#api.bg_tween_to_snapshot("stage_start", 2.0, "snappy")

	api.spawn_enemy(ENEMY_DATA, Vector2(500, -50))

	await api.seconds(3.0)
