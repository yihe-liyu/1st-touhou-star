extends RefCounted
class_name StageAPI
## 协程 API —— seconds/frames 直接返回等待秒数（不再 await）
##
## 返回值约定（配合 CoroutineRunner 调度器）：
##   seconds(t) → 返回 float 秒数，runner 自动倒计时
##   frames(n)  → 返回等价秒数

var runner: CoroutineRunner

func _init(p_runner: CoroutineRunner) -> void:
	runner = p_runner

func active() -> bool:
	return is_instance_valid(runner) and runner.is_running

func seconds(duration: float) -> float:
	return duration

func frames(count: int) -> float:
	return float(count) / Engine.physics_ticks_per_second

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

func spawn_enemy(data: EnemyData, position: Vector2) -> Enemy:
	if not active():
		return null
	return StageManager.spawn_enemy(data, position)

func get_player() -> Player:
	return GameState.player

func get_field_rect() -> Rect2:
	if not is_instance_valid(runner):
		return Rect2()
	return runner.get_viewport().get_visible_rect()

func all_defeated() -> bool:
	return GameState.active_enemies.is_empty()
