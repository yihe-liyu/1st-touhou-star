extends MoveScript
class_name MoveHoming

## 诱导角度每秒（弧度）
@export var homing_angle_per_sec: float = deg_to_rad(720)
## 加速到最高速所需时间（秒）
@export var accel_time: float = 2.0
## 最低速度
@export var min_speed: float = 500.0
## 最高速度（0=用当前速度）
@export var max_speed: float = 2000.0
## 诱导持续时间（秒，0=无限）
@export var homing_duration: float = 1.5
## 距离小于此值（px）时开始激进转弯
@export var proximity_boost: float = 150.0

var _elapsed: float = 0.0


func start_moving(p_ctx: StageContext, p_target: Node2D):
	ctx = p_ctx
	target = p_target
	_elapsed = 0.0
	
	# 用时间线来描述移动行为
	var tl := start_timeline()
	var base_speed: float = target.velocity.length()
	var top_speed: float = max_speed if max_speed > 0.0 else base_speed
	
	tl.every(0).do(func():
		if not ctx.active() or not is_instance_valid(target):
			return false
		
		var dt := get_physics_process_delta_time()
		_elapsed += dt
		
		var turn_factor := 1.0 if accel_time <= 0.0 else clampf(_elapsed / accel_time, 0.0, 1.0)
		var current_speed := lerpf(min_speed, top_speed, turn_factor)
		
		var still_homing := homing_duration <= 0.0 or _elapsed <= homing_duration
		if still_homing:
			var nearest := _find_nearest_enemy()
			if nearest:
				var to_target := nearest.global_position - target.global_position
				var dist: float = to_target.length()
				var desired_dir := to_target.normalized()
				var current_dir: Vector2 = target.velocity.normalized()
				var angle_diff: float = current_dir.angle_to(desired_dir)
				
				var dist_boost: float = clampf(proximity_boost / maxf(dist, 1.0), 1.0, 2.5)
				var max_turn := homing_angle_per_sec * turn_factor * dist_boost * dt
				var actual_turn := clampf(angle_diff, -max_turn, max_turn)
				
				var alignment := (current_dir.dot(desired_dir) + 1.0) * 0.4
				var speed_mult := lerpf(0.5, 1.0, alignment)
				
				target.velocity = current_dir.rotated(actual_turn) * current_speed * speed_mult
			else:
				target.velocity = target.velocity.normalized() * current_speed
		
		target.global_position += target.velocity * dt
		target.rotation = target.velocity.angle()
	)
	
	run(_on_step.bind(ctx))


func _on_step(_ctx: StageContext) -> Variant:
	if _tl:
		_tl.tick(get_physics_process_delta_time())
	return true


func _find_nearest_enemy() -> Node2D:
	var nearest: Node2D = null
	var nearest_dist := INF
	for enemy in GameState.active_enemies:
		if not is_instance_valid(enemy):
			continue
		if enemy is Boss:
			var phase = (enemy as Boss).current_phase()
			if phase and phase.is_timeout_only:
				continue
		var dist := target.global_position.distance_squared_to(enemy.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = enemy
	return nearest
