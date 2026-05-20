extends MoveScript
class_name TestMove

func _on_run(api: StageAPI):
	await api.move_to(enemy, Vector2(640, 200), 2.0)
	await api.seconds(0.5)
	await api.move_to(enemy, Vector2(320, 400), 1.5)
	await api.move_off_screen(enemy, Vector2.UP, 200)
