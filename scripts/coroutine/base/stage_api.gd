extends RefCounted
class_name StageAPI

var runner: CoroutineRunner

func _init(p_runner: CoroutineRunner) -> void:
	runner = p_runner

func _await_next_frame() -> bool:
	while is_instance_valid(runner) and runner.is_running:
		await runner.get_tree().physics_frame
		if not is_instance_valid(runner) or not runner.is_running:
			return false
		if not runner.get_tree().paused:
			return true
	return false

func active() -> bool:
	return is_instance_valid(runner) and runner.is_running

func seconds(duration: float) -> void:
	await frames(maxi(int(duration * Engine.physics_ticks_per_second), 1))

func frames(count: int) -> void:
	for _i in range(count):
		if not await _await_next_frame():
			return

func all_defeated() -> void:
	if not active():
		return
	
	var since_check := 0
	
	while active():
		# 快速检查：没有敌人了就直接返回
		if GameState.active_enemies.is_empty():
			return
		
		# 每 30 帧强检一次（兜底，防止 stop() 时卡死）
		if since_check >= 30:
			since_check = 0
			if not await _await_next_frame():
				return
		else:
			since_check += 1
			# 等待敌人被杀信号 —— 真正的信号驱动！
			await GameEvents.enemy_killed
			if not active():
				return
			since_check = 0

func spawn_enemy(data: EnemyData, position: Vector2) -> Enemy:
	if not active():
		return null
	return StageManager.spawn_enemy(data, position)

func shoot_spread(bullet_data: BulletData, count: int, spread_angle: float, base_dir: Vector2, at: Vector2) -> void:
	if not active():
		return
	if count <= 0:
		return
	if count == 1:
		BulletManager.shoot_enemy_bullet(bullet_data, at, base_dir)
		return
	var step: float
	if spread_angle >= TAU - 0.001:
		step = spread_angle / count
	else:
		step = spread_angle / (count - 1)
	for i in range(count):
		var angle_offset = - spread_angle / 2.0 + step * i
		var dir := base_dir.rotated(angle_offset)
		BulletManager.shoot_enemy_bullet(bullet_data, at, dir)

func get_player() -> Player:
	return GameState.player

func get_field_rect() -> Rect2:
	if not is_instance_valid(runner):
		return Rect2()
	return runner.get_viewport().get_visible_rect()
