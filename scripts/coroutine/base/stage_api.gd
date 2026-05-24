extends RefCounted
class_name StageAPI

const EASING_MAP = {
	"linear":     [Tween.EASE_IN,     Tween.TRANS_LINEAR],
	"smooth":     [Tween.EASE_IN_OUT, Tween.TRANS_SINE],
	"snappy":     [Tween.EASE_OUT,    Tween.TRANS_BACK],
	"bounce":     [Tween.EASE_OUT,    Tween.TRANS_BOUNCE],
	"elastic":    [Tween.EASE_OUT,    Tween.TRANS_ELASTIC],
	"ease_in":    [Tween.EASE_IN,     Tween.TRANS_QUAD],
	"ease_out":   [Tween.EASE_OUT,    Tween.TRANS_QUAD],
	"ease_in_out":[Tween.EASE_IN_OUT, Tween.TRANS_QUAD],
}

var runner: CoroutineRunner
var _bg: StageBackground = null
var _props: Dictionary = {}

func _init(p_runner: CoroutineRunner) -> void:
	runner = p_runner

func set_background(bg: StageBackground):
	_bg = bg
	_build_prop_registry()

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

# ═══════════════════════════════════════════════
# 属性注册表
# ═══════════════════════════════════════════════

func _build_prop_registry():
	if not _bg:
		return
	_props = {
		"fog.color":           [func(): return _bg.get_fog_color(),            func(v): _bg.set_fog_color(v)],
		"fog.density":         [func(): return _bg.get_fog_density(),          func(v): _bg.set_fog_density(v)],
		"fog.height_density":  [func(): return _bg.get_fog_height_density(),   func(v): _bg.set_fog_height_density(v)],
		"fog.depth_begin":     [func(): return _bg.get_fog_depth_begin(),      func(v): _bg.set_fog_depth_begin(v)],
		"fog.depth_end":       [func(): return _bg.get_fog_depth_end(),        func(v): _bg.set_fog_depth_end(v)],
		"camera.fov":          [func(): return _bg.get_camera_fov(),           func(v): _bg.set_camera_fov(v)],
		"camera.position":     [func(): return _bg.get_camera_position(),      func(v): _bg.set_camera_position(v)],
		"camera.rotation":     [func(): return _bg.get_camera_rotation_degrees(), func(v): _bg.set_camera_rotation_degrees(v)],
		"ground.scroll":       [func(): return _bg.get_ground_scroll(),        func(v): _bg.set_ground_scroll(v)],
		"ground.grid_scale":   [func(): return _bg.get_ground_grid_scale(),    func(v): _bg.set_ground_grid_scale(v)],
		"ground.line_width":   [func(): return _bg.get_ground_line_width(),    func(v): _bg.set_ground_line_width(v)],
		"ground.grid_color":   [func(): return _bg.get_ground_grid_color(),    func(v): _bg.set_ground_grid_color(v)],
		"ground.tint":         [func(): return _bg.get_ground_tint(),          func(v): _bg.set_ground_tint(v)],
		"ground.fov_stretch":  [func(): return _bg.get_fov_stretch(),          func(v): _bg.set_fov_stretch(v)],
		"ground.roll":         [func(): return _bg.get_roll(),                 func(v): _bg.set_roll(v)],
		"ground.speed_mult":   [func(): return _bg.get_camera_speed_mult(),    func(v): _bg.set_camera_speed_mult(v)],
		"sky.scroll":          [func(): return _bg.get_sky_scroll(),           func(v): _bg.set_sky_scroll(v)],
		"sky.tint":            [func(): return _bg.get_sky_tint(),             func(v): _bg.set_sky_tint(v)],
		"time_scale":          [func(): return _bg.get_time_scale(),           func(v): _bg.set_time_scale(v)],
		"ambient_light":       [func(): return _bg.get_ambient_light(),        func(v): _bg.set_ambient_light(v)],
		"screen.vignette":     [func(): return _bg.get_vignette(),             func(v): _bg.set_vignette(v)],
		"screen.overlay":      [func(): return _bg.get_overlay_color(),        func(v): _bg.set_overlay_color(v)],
	}

# ═══════════════════════════════════════════════
# 通用属性读写（替代所有 bg_set_xxx / bg_get_xxx）
# ═══════════════════════════════════════════════

func bg_set(path: String, value):
	if not _bg:
		return
	if path.begins_with("layer."):
		_set_layer_prop(path, value)
	elif _props.has(path):
		_props[path][1].call(value)

func bg_get(path: String):
	if not _bg:
		return null
	if path.begins_with("layer."):
		return _get_layer_prop(path)
	if _props.has(path):
		return _props[path][0].call()
	return null

func _set_layer_prop(path: String, value):
	var parsed = _parse_layer_path(path)
	if parsed == null:
		return
	var idx = parsed[0]
	var prop = parsed[1]
	match prop:
		"scroll":         _bg.set_layer_scroll(idx, value)
		"tint":           _bg.set_layer_tint(idx, value)
		"z_pos":          _bg.set_layer_z_pos(idx, value)
		"scale":          _bg.set_layer_scale(idx, value)
		"blend_strength": _bg.set_layer_blend_strength(idx, value)
		"visible":        _bg.set_layer_visible(idx, value)

func _get_layer_prop(path: String):
	var parsed = _parse_layer_path(path)
	if parsed == null:
		return null
	var idx = parsed[0]
	var prop = parsed[1]
	match prop:
		"scroll":         return _bg.get_layer_scroll(idx)
		"tint":           return _bg.get_layer_tint(idx)
		"z_pos":          return _bg.get_layer_z_pos(idx)
		"scale":          return _bg.get_layer_scale(idx)
		"blend_strength": return _bg.get_layer_blend_strength(idx)
	return null

func _parse_layer_path(path: String):
	var parts = path.split(".")
	if parts.size() != 3 or parts[0] != "layer":
		return null
	if not parts[1].is_valid_int():
		return null
	return [int(parts[1]), parts[2]]

# ═══════════════════════════════════════════════
# 通用 Tween（替代所有 bg_tween_xxx）
# ═══════════════════════════════════════════════

func bg_tween(path_or_dict, target = null, duration: float = 1.0, easing: String = "smooth") -> Tween:
	if not _bg:
		return _bg_runner_tween()

	if typeof(path_or_dict) == TYPE_DICTIONARY:
		return _bg_tween_multi_inner(path_or_dict, duration, easing)

	return _bg_tween_single(path_or_dict, target, duration, easing)

func _bg_tween_single(path: String, target, duration: float, easing: String) -> Tween:
	var tw = _bg_runner_tween()
	var current

	if path.begins_with("layer."):
		var parsed = _parse_layer_path(path)
		if parsed == null:
			return tw
		var _idx = parsed[0]
		var _prop = parsed[1]
		current = _get_layer_prop(path)
		var setter = func(v): _set_layer_prop(path, v)
		tw.tween_method(setter, current, target, duration)
	else:
		_build_prop_registry()
		if not _props.has(path):
			return tw
		current = _props[path][0].call()
		tw.tween_method(_props[path][1], current, target, duration)

	_apply_easing(tw, easing)
	return tw

func _bg_tween_multi_inner(properties: Dictionary, duration: float, easing: String) -> Tween:
	var tw = _bg_runner_tween()
	for path in properties:
		var target = properties[path]
		var current

		if path.begins_with("layer."):
			current = _get_layer_prop(path)
			var setter = func(v): _set_layer_prop(path, v)
			tw.tween_method(setter, current, target, duration)
		else:
			_build_prop_registry()
			if not _props.has(path):
				continue
			current = _props[path][0].call()
			tw.tween_method(_props[path][1], current, target, duration)

	_apply_easing(tw, easing)
	return tw

func _bg_runner_tween() -> Tween:
	assert(is_instance_valid(runner), "StageAPI: runner is not valid")
	return runner.create_tween()

func _apply_easing(tw: Tween, easing: String):
	var e = EASING_MAP.get(easing, EASING_MAP["smooth"])
	tw.set_ease(e[0]).set_trans(e[1])

# ═══════════════════════════════════════════════
# 特殊方法（不适合通用入口的）
# ═══════════════════════════════════════════════

# ── 层创建 / 销毁 ──

func bg_add_layer(texture: Texture2D, scroll: Vector2 = Vector2(0, -0.1), z_pos: float = 10.0, scale: float = 2.0, tint: Color = Color.WHITE, blend_mode: String = "normal") -> int:
	if not _bg: return -1
	var bm = 0
	match blend_mode:
		"add": bm = 1
		"multiply": bm = 2
	return _bg.add_scroll_layer(texture, scroll, z_pos, scale, tint, bm)

func bg_clear_layers():
	if _bg: _bg.clear_layers()

func bg_remove_layer(layer_index: int):
	if _bg: _bg.remove_layer(layer_index)

func bg_get_layer_count() -> int:
	if _bg: return _bg.get_layer_count()
	return 0

# ── 天空 / 地面 / 雾（多参数 setup 型） ──

func bg_set_sky(texture: Texture2D, scroll: Vector2 = Vector2(0, -0.02), scale: float = 3.0, tint: Color = Color.WHITE):
	if _bg: _bg.set_sky(texture, scroll, scale, tint)

func bg_set_ground(texture: Texture2D, scroll: Vector2 = Vector2(0, -0.2), grid_scale: float = 20.0, line_width: float = 0.03, grid_color: Color = Color(0.3, 0.5, 1.0, 0.0), tint: Color = Color.WHITE):
	if _bg: _bg.set_ground(texture, scroll, grid_scale, line_width, grid_color, tint)

func bg_set_fog(color: Color = Color(0.49, 0.42, 0.67, 1), density: float = 1.0, height_density: float = 0.5, depth_begin: float = 3.0, depth_end: float = 35.0, bg_color: Color = Color(0.15, 0.15, 0.31, 1)):
	if _bg: _bg.set_fog(color, density, height_density, depth_begin, depth_end, bg_color)

# ── 震动 ──

func bg_shake(amplitude: float = 2.0, decay: float = 4.0):
	if _bg: _bg.trigger_shake(amplitude, decay)

func bg_setup_camera():
	if _bg: _bg.setup_camera()

func bg_reset_camera():
	if _bg: _bg.reset_camera()

# ── 快照 ──

func bg_save_snapshot(name: String):
	if _bg: _bg.save_snapshot(name)

func bg_load_snapshot(name: String):
	if _bg: _bg.load_snapshot(name)

func bg_tween_to_snapshot(name: String, duration: float, easing: String = "smooth") -> Tween:
	if not _bg or not _bg.has_snapshot(name):
		return _bg_runner_tween()

	var snap = _bg._snapshots[name]
	var diffs = {}
	for key in snap:
		var target = snap[key]
		var current = _bg.get_snapshot_property_value(key)
		if current == null:
			continue
		if typeof(current) == TYPE_COLOR:
			if current.is_equal_approx(target):
				continue
		elif typeof(current) == TYPE_VECTOR2 or typeof(current) == TYPE_VECTOR3:
			if current.distance_to(target) < 0.0001:
				continue
		elif current == target:
			continue
		diffs[key] = target

	if diffs.is_empty():
		return _bg_runner_tween()

	var tw = _bg_runner_tween()
	for key in diffs:
		var target_val = diffs[key]
		var current_val = _bg.get_snapshot_property_value(key)
		var setter = func(v): _bg._apply_snapshot_property(key, v)
		tw.tween_method(setter, current_val, target_val, duration)

	_apply_easing(tw, easing)
	return tw

# ── 屏幕特效 ──

func bg_screen_flash(color: Color, hold_duration: float = 0.1):
	if _bg: _bg.screen_flash(color, hold_duration)

func bg_screen_freeze_frame(count: int = 3):
	var original_scale = 1.0
	if _bg:
		original_scale = _bg.get_time_scale()
		_bg.set_time_scale(0.0)
		await frames(count)
		_bg.set_time_scale(original_scale)
