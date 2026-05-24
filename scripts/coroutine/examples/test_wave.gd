extends StageScript
class_name TestLevel

const ENEMY_DATA = preload("res://data/enemy_data/test_enemy_data.tres")
const BG_GROUND = preload("res://assets/Textures/background/stage01/st01a.png")
const BG_LAYER = preload("res://assets/Textures/background/stage01/st01b.png")

func _on_run(api: StageAPI):

	api.spawn_enemy(ENEMY_DATA, Vector2(640, -50))

	await api.seconds(3.0)

	api.spawn_enemy(ENEMY_DATA, Vector2(300, -50))

	await api.seconds(3.0)

	#api.bg_tween_to_snapshot("stage_start", 2.0, "snappy")

	api.spawn_enemy(ENEMY_DATA, Vector2(500, -50))

	await api.seconds(3.0)
