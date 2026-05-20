extends RefCounted
class_name StageAPI

var runner: CoroutineRunner

func _init(p_runner: CoroutineRunner) -> void:
	runner = p_runner

func _active() -> bool:
	return runner != null and runner.is_running

func seconds(duration: float) -> void:
	if not _active():
		return
	await runner.get_tree().create_timer(duration).timeout

func frames(count: int) -> void:
	if not _active():
		return
	for _i in range(count):
		if not _active():
			return
		await runner.get_tree().process_frame

func all_defeated() -> void:
	while _active():
		var has_alive := false
		for enemy in GameState.active_enemies:
			if is_instance_valid(enemy):
				has_alive = true
				break
		if not has_alive:
			break
		await runner.get_tree().process_frame

func spawn_enemy(data: EnemyData, position: Vector2) -> Enemy:
	return LevelManager.spawn_enemy(data, position)

func shoot_circle(bullet_data: BulletData, count: int, speed: float, at: Vector2) -> void:
	for i in range(count):
		var dir := Vector2.RIGHT.rotated(TAU / count * i)
		BulletManager.shoot_enemy_bullet(bullet_data, at, dir)

func shoot_aimed(bullet_data: BulletData, count: int, spread_angle: float, speed: float, at: Vector2) -> void:
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
	BulletManager.shoot_enemy_bullet(bullet_data, at, direction)

func move_to(enemy: Enemy, target: Vector2, duration: float) -> void:
	if not _active():
		return
	var start_pos := enemy.global_position
	var prev_time := Time.get_ticks_msec()
	var elapsed := 0.0
	while _active() and elapsed < duration:
		await runner.get_tree().process_frame
		if not _active():
			return
		var now := Time.get_ticks_msec()
		var delta := (now - prev_time) / 1000.0
		prev_time = now
		elapsed += delta
		var t := clampf(elapsed / duration, 0.0, 1.0)
		enemy.global_position = start_pos.lerp(target, t)
	enemy.global_position = target

func move_off_screen(enemy: Enemy, direction: Vector2, speed: float) -> void:
	if not _active():
		return
	var viewport_rect := runner.get_viewport().get_visible_rect()
	var margin := 90.0
	var prev_time := Time.get_ticks_msec()
	while _active() and is_instance_valid(enemy):
		var pos := enemy.global_position
		if pos.x < -margin or pos.x > viewport_rect.size.x + margin or pos.y < -margin or pos.y > viewport_rect.size.y + margin:
			break
		await runner.get_tree().process_frame
		if not _active() or not is_instance_valid(enemy):
			return
		var now := Time.get_ticks_msec()
		var delta := (now - prev_time) / 1000.0
		prev_time = now
		enemy.global_position += direction.normalized() * speed * delta

func get_player() -> Player:
	return GameState.player

func get_field_rect() -> Rect2:
	return runner.get_viewport().get_visible_rect()
