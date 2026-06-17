extends MoveScript
class_name MoveHoming

@export var homing_angle_per_sec: float = deg_to_rad(720)
@export var accel_time: float = 2.0
@export var min_speed: float = 500.0
@export var max_speed: float = 2000.0
@export var homing_duration: float = 1.5
## 距离越近诱导越强：1/距离的权重
@export var proximity_boost: float = 150.0  # px，距离小于此值开始激进转弯

var _elapsed: float = 0.0
var _base_speed: float
var _max_speed: float

func start_moving(api: StageAPI, p_target: Node2D):
	target = p_target
	_elapsed = 0.0
	_base_speed = target.velocity.length()
	_max_speed = max_speed if max_speed > 0.0 else _base_speed
	run(_on_step.bind(api))

func _on_step(api: StageAPI) -> Variant:
	if not api.active() or not is_instance_valid(target):
		return false

	_elapsed += 1.0 / Engine.physics_ticks_per_second

	var turn_factor := 1.0 if accel_time <= 0.0 else clampf(_elapsed / accel_time, 0.0, 1.0)
	var speed_factor := turn_factor
	var current_speed := lerpf(min_speed, _max_speed, speed_factor)

	var still_homing := homing_duration <= 0.0 or _elapsed <= homing_duration
	if still_homing:
		var nearest := _find_nearest_enemy()
		if nearest:
			var to_target := nearest.global_position - target.global_position
			var dist: float = to_target.length()
			var desired_dir := to_target.normalized()
			var current_dir: Vector2 = target.velocity.normalized()
			var angle_diff: float = current_dir.angle_to(desired_dir)

			# 越近转越猛（防止远距离绕圈、近距离够不到）
			var dist_boost: float = clampf(proximity_boost / maxf(dist, 1.0), 1.0, 2.5)
			var max_turn := homing_angle_per_sec * turn_factor * dist_boost / Engine.physics_ticks_per_second
			var actual_turn := clampf(angle_diff, -max_turn, max_turn)

			# 方向差大时降速，防冲过头
			var alignment := (current_dir.dot(desired_dir) + 1.0) * 0.4  # 0=反, 0.5=横, 1=正
			var speed_mult := lerpf(0.5, 1.0, alignment)

			target.velocity = current_dir.rotated(actual_turn) * current_speed * speed_mult
		else:
			target.velocity = target.velocity.normalized() * current_speed

	target.global_position += target.velocity / Engine.physics_ticks_per_second
	target.rotation = target.velocity.angle()
	return true

func _find_nearest_enemy() -> Node2D:
	var nearest: Node2D = null
	var nearest_dist := INF
	for enemy in GameState.active_enemies:
		if not is_instance_valid(enemy):
			continue
		# 时符阶段跳过 Boss，不诱导
		if enemy is Boss:
			var phase = (enemy as Boss).current_phase()
			if phase and phase.is_timeout_only:
				continue
		var dist := target.global_position.distance_squared_to(enemy.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = enemy
	return nearest
