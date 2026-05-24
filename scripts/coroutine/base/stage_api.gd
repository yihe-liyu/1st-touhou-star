extends RefCounted
class_name StageAPI

var runner: CoroutineRunner
var _bg_cache = null

func _init(p_runner: CoroutineRunner) -> void:
	runner = p_runner

func set_background(bg) -> void:
	_bg_cache = bg

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

func _get_bg():
	if not _active():
		return null
	if _bg_cache and is_instance_valid(_bg_cache):
		return _bg_cache
	if not is_instance_valid(runner):
		return null
	var tree = runner.get_tree()
	if not tree:
		return null
	var bg = tree.get_first_node_in_group("stage_background")
	if not bg:
		push_warning("StageAPI: stage_background not found in scene tree")
		return null
	_bg_cache = bg
	return bg

func bg_add_quad(texture: Texture2D, config: Dictionary = {}) -> int:
	if not _active():
		return 0
	var bg = _get_bg()
	if not bg:
		return 0
	return bg.add_quad(texture, config)

func bg_remove_quad(index: int) -> void:
	if not _active():
		return
	var bg = _get_bg()
	if not bg:
		return
	bg.remove_quad(index)

func bg_get_quad_count() -> int:
	if not _active():
		return 0
	var bg = _get_bg()
	if not bg:
		return 0
	return bg.get_quad_count()

func bg_add_particle(config: Resource) -> int:
	if not _active():
		return 0
	var bg = _get_bg()
	if not bg:
		return 0
	return bg.add_particle(config)

func bg_remove_particle(index: int) -> void:
	if not _active():
		return
	var bg = _get_bg()
	if not bg:
		return
	bg.remove_particle(index)

func bg_get_particle_count() -> int:
	if not _active():
		return 0
	var bg = _get_bg()
	if not bg:
		return 0
	return bg.get_particle_count()

func bg_clear() -> void:
	if not _active():
		return
	var bg = _get_bg()
	if not bg:
		return
	bg.clear_all()

func bg_set_quad_pos(index: int, pos: Vector3, duration: float = 0.0) -> void:
	if not _active():
		return
	var bg = _get_bg()
	if not bg:
		return
	bg.set_quad_position(index, pos, duration)

func bg_set_quad_rot(index: int, rot: Vector3, duration: float = 0.0) -> void:
	if not _active():
		return
	var bg = _get_bg()
	if not bg:
		return
	bg.set_quad_rotation(index, rot, duration)

func bg_set_quad_size(index: int, size: Vector2) -> void:
	if not _active():
		return
	var bg = _get_bg()
	if not bg:
		return
	bg.set_quad_size(index, size)

func bg_set_quad_scroll(index: int, scroll: Vector3, duration: float = 0.0) -> void:
	if not _active():
		return
	var bg = _get_bg()
	if not bg:
		return
	bg.set_quad_scroll(index, scroll, duration)

func bg_set_quad_color(index: int, color: Color, duration: float = 0.0) -> void:
	if not _active():
		return
	var bg = _get_bg()
	if not bg:
		return
	bg.set_quad_color(index, color, duration)

func bg_set_quad_texture(index: int, texture: Texture2D) -> void:
	if not _active():
		return
	var bg = _get_bg()
	if not bg:
		return
	bg.set_quad_texture(index, texture)

func bg_set_quad_visible(index: int, visible: bool, duration: float = 0.0) -> void:
	if not _active():
		return
	var bg = _get_bg()
	if not bg:
		return
	bg.set_quad_visible(index, visible, duration)

func bg_set_quad_tile(index: int, tile: Vector2) -> void:
	if not _active():
		return
	var bg = _get_bg()
	if not bg:
		return
	bg.set_quad_tile(index, tile)

func bg_fade_quad(index: int, target, duration: float = 0.5) -> void:
	if not _active():
		return
	var bg = _get_bg()
	if not bg:
		return
	bg.fade_quad(index, target, duration)

func bg_set_fog(color: Color, density: float, begin: float, end: float, duration: float = 0.0) -> void:
	if not _active():
		return
	var bg = _get_bg()
	if not bg:
		return
	bg.set_fog(color, density, begin, end, duration)

func bg_shake(intensity: float, duration: float) -> void:
	if not _active():
		return
	var bg = _get_bg()
	if not bg:
		return
	bg.shake(intensity, duration)

func bg_set_front_texture(texture: Texture2D, duration: float = 0.0) -> void:
	if not _active():
		return
	var bg = _get_bg()
	if not bg:
		return
	bg.set_front_texture(texture, duration)

func bg_fade_in(duration: float = 1.5) -> void:
	if not _active():
		return
	var bg = _get_bg()
	if not bg:
		return
	bg.fade_in(duration)

func bg_fade_out(duration: float = 1.5) -> void:
	if not _active():
		return
	var bg = _get_bg()
	if not bg:
		return
	bg.fade_out(duration)

func bg_load_preset(data) -> void:
	if not _active():
		return
	var bg = _get_bg()
	if not bg:
		return
	bg.load_preset(data)

func bg_transition_to(data, duration: float = 1.5) -> void:
	if not _active():
		return
	var bg = _get_bg()
	if not bg:
		return
	bg.transition_to(data, duration)
