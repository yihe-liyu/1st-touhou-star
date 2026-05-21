extends LevelScript
class_name TestLevel

const ENEMY_DATA = preload("res://data/enemy_data/test_enemy_data.tres")

func _on_run(api: StageAPI):
	api.spawn_enemy(ENEMY_DATA, Vector2(640, -50))

	await api.seconds(3.0)

	api.spawn_enemy(ENEMY_DATA, Vector2(300, -50))

	await api.seconds(3.0)

	await api.all_defeated()
