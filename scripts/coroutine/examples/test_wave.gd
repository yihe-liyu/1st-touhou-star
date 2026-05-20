extends WaveScript
class_name TestWave

func _on_run(api: StageAPI):
	var wave = LevelManager.get_wave()
	if wave and wave.enemy_data:
		api.spawn_enemy(wave.enemy_data, Vector2(640, -50))
		await api.seconds(0.5)
		api.spawn_enemy(wave.enemy_data, Vector2(300, -50))
		await api.seconds(1.5)

	await api.all_defeated()
