extends MoveScript
class_name MoveHoming

@export var homing_angle_per_sec: float = deg_to_rad(300)
@export var accel_time: float = 2
@export var min_speed: float = 500.0
@export var max_speed: float = 1500.0
@export var homing_duration: float = 1.0

func _on_run(api: StageAPI):
	var elapsed: float = 0.0
	var base_speed = target.velocity.length()
	var _max_speed = max_speed if max_speed > 0.0 else base_speed
	while api._active() and is_instance_valid(target):
		elapsed += 1.0 / 60.0
		var turn_factor = 1.0 if accel_time <= 0.0 else clampf(elapsed / accel_time, 0.0, 1.0)
		var speed_factor = 1.0 if accel_time <= 0.0 else clampf(elapsed / accel_time, 0.0, 1.0)
		var current_speed = lerpf(min_speed, _max_speed, speed_factor)

		var still_homing = homing_duration <= 0.0 or elapsed <= homing_duration
		if still_homing:
			var nearest = _find_nearest_enemy()
			if nearest:
				var desired_dir = (nearest.global_position - target.global_position).normalized()
				var current_dir = target.velocity.normalized()
				var angle_diff = current_dir.angle_to(desired_dir)
				var max_turn = homing_angle_per_sec * turn_factor / 10
				var actual_turn = clampf(angle_diff, -max_turn, max_turn)
				target.velocity = current_dir.rotated(actual_turn) * current_speed
			else:
				target.velocity = target.velocity.normalized() * current_speed
		target.global_position += target.velocity / 60.0
		target.rotation = target.velocity.angle()
		await api.frames(1)

func _find_nearest_enemy() -> Node2D:
	var nearest: Node2D = null
	var nearest_dist := INF
	for enemy in GameState.active_enemies:
		if not is_instance_valid(enemy):
			continue
		var dist = target.global_position.distance_squared_to(enemy.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = enemy
	return nearest
