extends RefCounted
class_name StageAPI

var runner: CoroutineRunner

func _init(p_runner: CoroutineRunner) -> void:
	runner = p_runner

func _active() -> bool:
	return is_instance_valid(runner) and runner.is_running

func _await_next_frame() -> bool:
	while is_instance_valid(runner) and runner.is_running:
		await runner.get_tree().physics_frame
		if not is_instance_valid(runner) or not runner.is_running:
			return false
		if not runner.get_tree().paused:
			return true
	return false

func seconds(duration: float) -> void:
	await frames(maxi(int(duration * 60.0), 1))

func frames(count: int) -> void:
	for _i in range(count):
		if not await _await_next_frame():
			return

func all_defeated() -> void:
	while _active():
		var has_alive := false
		for enemy in GameState.active_enemies:
			if is_instance_valid(enemy):
				has_alive = true
				break
		if not has_alive:
			break
		if not await _await_next_frame():
			return

func spawn_enemy(data: EnemyData, position: Vector2) -> Enemy:
	if not _active():
		return null
	return LevelManager.spawn_enemy(data, position)

func shoot_circle(bullet_data: BulletData, count: int, at: Vector2) -> void:
	if not _active():
		return
	for i in range(count):
		var dir := Vector2.RIGHT.rotated(TAU / count * i)
		BulletManager.shoot_enemy_bullet(bullet_data, at, dir)

func shoot_aimed(bullet_data: BulletData, count: int, spread_angle: float, at: Vector2) -> void:
	if not _active():
		return
	var player := GameState.player
	var base_dir: Vector2
	if is_instance_valid(player):
		base_dir = (player.global_position - at).normalized()
	else:
		base_dir = Vector2.DOWN
	for i in range(count):
		var angle_offset: float
		if count > 1:
			angle_offset = -spread_angle / 2.0 + spread_angle / (count - 1) * i
		else:
			angle_offset = 0.0
		var dir := base_dir.rotated(angle_offset)
		BulletManager.shoot_enemy_bullet(bullet_data, at, dir)

func shoot_direction(bullet_data: BulletData, direction: Vector2, at: Vector2) -> void:
	if not _active():
		return
	BulletManager.shoot_enemy_bullet(bullet_data, at, direction)

func get_player() -> Player:
	return GameState.player

func get_field_rect() -> Rect2:
	if not is_instance_valid(runner):
		return Rect2()
	return runner.get_viewport().get_visible_rect()
