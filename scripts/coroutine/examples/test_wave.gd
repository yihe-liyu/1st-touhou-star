extends WaveScript
class_name TestWave

func _on_run(api: StageAPI):
	var wave = LevelManager.get_wave()
	if not wave or not wave.enemy_data:
		return

	var e1 = api.spawn_enemy(wave.enemy_data, Vector2(640, -50))
	if not is_running:
		return
	await api.move_to(e1, Vector2(640, 200), 2.0)

	if not is_running:
		return
	await api.seconds(0.5)

	var e2 = api.spawn_enemy(wave.enemy_data, Vector2(300, -50))
	if not is_running:
		return
	await api.move_to(e2, Vector2(300, 200), 2.0)

	if not is_running:
		return
	await api.seconds(1.0)

	await api.all_defeated()
