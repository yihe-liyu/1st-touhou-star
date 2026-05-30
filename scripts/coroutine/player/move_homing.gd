extends MoveScript
class_name MoveHoming

@export var homing_angle_per_sec: float = deg_to_rad(720)
@export var accel_time: float = 2.0
@export var min_speed: float = 500.0
@export var max_speed: float = 2000.0
@export var homing_duration: float = 1.5

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
	var speed_factor := turn_factor  # same curve
	var current_speed := lerpf(min_speed, _max_speed, speed_factor)

	var still_homing := homing_duration <= 0.0 or _elapsed <= homing_duration
	if still_homing:
		var nearest := _find_nearest_enemy()
		if nearest:
			var desired_dir := (nearest.global_position - target.global_position).normalized()
			var current_dir: Vector2 = target.velocity.normalized()
			# 每帧 lerp 一点点朝向敌人，不绕圈
			var strength: float = homing_angle_per_sec * turn_factor / Engine.physics_ticks_per_second
			var new_dir := current_dir.lerp(desired_dir, strength).normalized()
			target.velocity = new_dir * current_speed
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
		var dist := target.global_position.distance_squared_to(enemy.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = enemy
	return nearest
