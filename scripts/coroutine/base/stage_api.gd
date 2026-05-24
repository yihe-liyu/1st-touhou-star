extends RefCounted
class_name StageAPI

var runner: CoroutineRunner
var _bg: StageBackground = null

func _init(p_runner: CoroutineRunner) -> void:
	runner = p_runner

func set_background(bg: StageBackground):
	_bg = bg

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
	return StageManager.spawn_enemy(data, position)

func shoot_spread(bullet_data: BulletData, count: int, spread_angle: float, base_dir: Vector2, at: Vector2) -> void:
	if not _active():
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

# ── 背景：层 ──

func bg_add_layer(texture: Texture2D, scroll: Vector2 = Vector2(0, -0.1), z_pos: float = 10.0, scale: float = 2.0, tint: Color = Color.WHITE) -> int:
	if not _bg: return -1
	return _bg.add_scroll_layer(texture, scroll, z_pos, scale, tint)

func bg_clear_layers():
	if _bg: _bg.clear_layers()

func bg_set_scroll(layer_index: int, scroll: Vector2):
	if _bg: _bg.set_layer_scroll(layer_index, scroll)

func bg_set_tint(layer_index: int, tint: Color):
	if _bg: _bg.set_layer_tint(layer_index, tint)

func bg_set_layer_visible(layer_index: int, visible: bool):
	if _bg: _bg.set_layer_visible(layer_index, visible)

func bg_remove_layer(layer_index: int):
	if _bg: _bg.remove_layer(layer_index)

# ── 背景：天空 ──

func bg_set_sky(texture: Texture2D, scroll: Vector2 = Vector2(0, -0.02), scale: float = 3.0, tint: Color = Color.WHITE):
	if _bg: _bg.set_sky(texture, scroll, scale, tint)

func bg_set_sky_scroll(scroll: Vector2):
	if _bg: _bg.set_sky_scroll(scroll)

# ── 背景：地面 ──

func bg_set_ground(texture: Texture2D, scroll: Vector2 = Vector2(0, -0.2), grid_scale: float = 20.0, line_width: float = 0.03, grid_color: Color = Color(0.3, 0.5, 1.0, 0.0), tint: Color = Color.WHITE):
	if _bg: _bg.set_ground(texture, scroll, grid_scale, line_width, grid_color, tint)

func bg_set_ground_scroll(scroll: Vector2):
	if _bg: _bg.set_ground_scroll(scroll)

# ── 背景：雾 ──

func bg_set_fog(color: Color = Color(0.49, 0.42, 0.67, 1), density: float = 1.0, height_density: float = 0.5, depth_begin: float = 3.0, depth_end: float = 35.0, bg_color: Color = Color(0.15, 0.15, 0.31, 1)):
	if _bg: _bg.set_fog(color, density, height_density, depth_begin, depth_end, bg_color)

func bg_set_fog_color(color: Color):
	if _bg: _bg.set_fog_color(color)

func bg_set_fog_density(density: float):
	if _bg: _bg.set_fog_density(density)

# ── 背景：相机震动 ──

func bg_shake(amplitude: float = 2.0, decay: float = 4.0):
	if _bg: _bg.trigger_shake(amplitude, decay)

func bg_setup_camera():
	if _bg: _bg.setup_camera()

func bg_reset_camera():
	if _bg: _bg.reset_camera()

# ── 背景：摄像机位置 / 旋转 / FOV ──

func bg_set_camera_position(pos: Vector3):
	if _bg: _bg.set_camera_position(pos)

func bg_set_camera_rotation_degrees(rot: Vector3):
	if _bg: _bg.set_camera_rotation_degrees(rot)

func bg_set_camera_fov(fov: float):
	if _bg: _bg.set_camera_fov(fov)

# ═══════════════════════════════════════════════
# 背景 Tween 动画（所有 bg_tween_* 都在关卡脚本里 await 使用）
# ═══════════════════════════════════════════════

func _bg_runner_tween() -> Tween:
	# 确保 runner 是有效的 Node 以创建 Tween
	assert(is_instance_valid(runner), "StageAPI: runner is not valid")
	return runner.create_tween()

func bg_tween_fog_color(target: Color, duration: float) -> Tween:
	if not _bg: return _bg_runner_tween()
	var tw = _bg_runner_tween()
	tw.tween_method(_bg.set_fog_color, _bg.get_fog_color(), target, duration)
	return tw

func bg_tween_fog_density(target: float, duration: float) -> Tween:
	if not _bg: return _bg_runner_tween()
	var tw = _bg_runner_tween()
	tw.tween_method(_bg.set_fog_density, _bg.get_fog_density(), target, duration)
	return tw

func bg_tween_ground_scroll(target: Vector2, duration: float) -> Tween:
	if not _bg: return _bg_runner_tween()
	var tw = _bg_runner_tween()
	tw.tween_method(_bg.set_ground_scroll, _bg.get_ground_scroll(), target, duration)
	return tw

func bg_tween_sky_scroll(target: Vector2, duration: float) -> Tween:
	if not _bg: return _bg_runner_tween()
	var tw = _bg_runner_tween()
	tw.tween_method(_bg.set_sky_scroll, _bg.get_sky_scroll(), target, duration)
	return tw

func bg_tween_camera_rotation_degrees(target: Vector3, duration: float) -> Tween:
	if not _bg: return _bg_runner_tween()
	var tw = _bg_runner_tween()
	tw.tween_method(_bg.set_camera_rotation_degrees, _bg.get_camera_rotation_degrees(), target, duration)
	return tw

func bg_tween_camera_fov(target: float, duration: float) -> Tween:
	if not _bg: return _bg_runner_tween()
	var tw = _bg_runner_tween()
	tw.tween_method(_bg.set_camera_fov, _bg.get_camera_fov(), target, duration)
	return tw

func bg_tween_camera_position(target: Vector3, duration: float) -> Tween:
	if not _bg: return _bg_runner_tween()
	var tw = _bg_runner_tween()
	tw.tween_method(_bg.set_camera_position, _bg.get_camera_position(), target, duration)
	return tw

func bg_tween_layer_scroll(layer_index: int, target: Vector2, duration: float) -> Tween:
	if not _bg: return _bg_runner_tween()
	var tw = _bg_runner_tween()
	var getter = func(): return _bg.get_layer_scroll(layer_index)
	tw.tween_method(func(v): _bg.set_layer_scroll(layer_index, v), getter.call(), target, duration)
	return tw

func bg_tween_layer_tint(layer_index: int, target: Color, duration: float) -> Tween:
	if not _bg: return _bg_runner_tween()
	var tw = _bg_runner_tween()
	var getter = func(): return _bg.get_layer_tint(layer_index)
	tw.tween_method(func(v): _bg.set_layer_tint(layer_index, v), getter.call(), target, duration)
	return tw
