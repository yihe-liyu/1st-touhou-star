@tool
extends CanvasLayer
class_name StageBackground

const VIEWPORT_WIDTH: float = 776.0
const VIEWPORT_HEIGHT: float = 904.0
const WORLD_HEIGHT: float = 12.0
const WORLD_WIDTH: float = WORLD_HEIGHT * VIEWPORT_WIDTH / VIEWPORT_HEIGHT
const WORLD_UNIT_PER_PIXEL: float = WORLD_HEIGHT / VIEWPORT_HEIGHT
const CAMERA_REST_POSITION: Vector3 = Vector3(0, 2, 8)

class _QuadEntry:
	var config: Resource
	var mesh: MeshInstance3D
	var material: StandardMaterial3D
	var active_tweens: Array[Dictionary] = []

class _ParticleEntry:
	var config: Resource
	var particles: GPUParticles3D

@export var preview_data: Resource:
	set(v):
		preview_data = v
		if Engine.is_editor_hint() and v:
			load_preset(v)

var _quads: Array[_QuadEntry] = []
var _particles: Array[_ParticleEntry] = []
var _quads_node: Node3D
var _camera: Camera3D
var _world_env: WorldEnvironment
var _viewport_container: Control
var _paused: bool = false
var _shake_active: bool = false
var _shake_intensity: float = 0.0
var _shake_duration: float = 0.0
var _shake_elapsed: float = 0.0
var _foreground_layer: CanvasLayer
var _foreground_rect: TextureRect
var _old_quads_node: Node3D = null
var _old_quads: Array[_QuadEntry] = []
var _transition_tween: Tween = null

func _enter_tree():
	add_to_group("stage_background")

func _exit_tree():
	remove_from_group("stage_background")
	_kill_all_tweens()
	for q in _quads:
		if is_instance_valid(q.mesh):
			q.mesh.queue_free()
	for p in _particles:
		if is_instance_valid(p.particles):
			p.particles.queue_free()
	_quads.clear()
	_particles.clear()
	if _quads_node:
		_quads_node.queue_free()
	if _old_quads_node:
		_old_quads_node.queue_free()
	if GameManager.game_state_changed.is_connected(_on_game_state_changed):
		GameManager.game_state_changed.disconnect(_on_game_state_changed)

func _ready():
	if Engine.is_editor_hint():
		return

	_camera = %Camera3D
	_world_env = %WorldEnvironment
	_viewport_container = get_node_or_null("SubViewportContainer")

	_quads_node = Node3D.new()
	_quads_node.name = "BackgroundQuads"
	get_node("SubViewportContainer/SubViewport").add_child(_quads_node)

	_foreground_layer = CanvasLayer.new()
	_foreground_layer.layer = 10
	_foreground_rect = TextureRect.new()
	_foreground_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_foreground_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_foreground_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_foreground_layer.add_child(_foreground_rect)
	add_child(_foreground_layer)

	if not GameManager.game_state_changed.is_connected(_on_game_state_changed):
		GameManager.game_state_changed.connect(_on_game_state_changed)

func _notification(what: int):
	if what == 1025 and preview_data:
		if _quads.is_empty():
			load_preset(preview_data)

# ──  Quad CRUD  ──

func add_quad(texture: Texture2D, config: Dictionary = {}) -> int:
	if not texture:
		push_warning("StageBackground: add_quad called with null texture")
		return -1

	var quad_cfg = _make_quad_config(texture, config)

	var quad_mesh = QuadMesh.new()
	quad_mesh.size = quad_cfg.size
	quad_mesh.orientation = QuadMesh.FACE_Z

	var mat = StandardMaterial3D.new()
	mat.albedo_texture = texture
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = quad_cfg.color
	mat.uv1_scale = Vector3(quad_cfg.tile.x, quad_cfg.tile.y, 1.0)

	var instance = MeshInstance3D.new()
	instance.mesh = quad_mesh
	instance.material_override = mat
	instance.position = quad_cfg.position
	instance.rotation_degrees = quad_cfg.rotation

	if not _quads_node:
		_quads_node = Node3D.new()
		_quads_node.name = "BackgroundQuads"
		var vp = get_node_or_null("SubViewportContainer/SubViewport")
		if vp:
			vp.add_child(_quads_node)

	_quads_node.add_child(instance)

	var entry = _QuadEntry.new()
	entry.config = quad_cfg
	entry.mesh = instance
	entry.material = mat
	_quads.append(entry)

	return _quads.size() - 1

func _make_quad_config(texture: Texture2D, config: Dictionary) -> Resource:
	var cfg: Resource = preload("res://scripts/data/background_quad.gd").new()
	cfg.texture = texture
	cfg.position = config.get("pos", Vector3(0, 0, 10))
	cfg.rotation = config.get("rot", Vector3(0, 0, 0))

	var default_size = Vector2(WORLD_WIDTH, WORLD_HEIGHT)
	if config.has("size"):
		cfg.size = config["size"]
	else:
		cfg.size = default_size

	cfg.tile = config.get("tile", Vector2(1, 1))
	cfg.scroll = config.get("scroll", Vector3(0, 1, 0))
	cfg.color = config.get("color", Color.WHITE)
	return cfg

func remove_quad(index: int):
	if index < 0 or index >= _quads.size():
		return
	var entry = _quads[index]
	_kill_entry_tweens(entry)
	if is_instance_valid(entry.mesh):
		entry.mesh.queue_free()
	_quads.remove_at(index)

func get_quad_count() -> int:
	return _quads.size()

# ──  Particle CRUD  ──

func add_particle(config: Resource) -> int:
	if not config:
		push_warning("StageBackground: add_particle called with null config")
		return -1

	var particles = GPUParticles3D.new()
	particles.amount = config.amount
	particles.lifetime = config.lifetime
	particles.one_shot = config.one_shot
	particles.explosiveness = config.explosiveness
	particles.position = config.position

	var pm = ParticleProcessMaterial.new()
	pm.direction = Vector3(config.direction.x, config.direction.y, 0)
	pm.spread = config.spread
	pm.initial_velocity_min = config.speed_min
	pm.initial_velocity_max = config.speed_max
	pm.scale_min = config.scale_min
	pm.scale_max = config.scale_max
	pm.gravity = Vector3(config.gravity.x, config.gravity.y, 0)
	pm.color = config.modulate
	if config.has_method("get") or config.get("spawn_rect") != null:
		var sr: Rect2 = config.spawn_rect
		var ext = Vector3(
			sr.size.x * WORLD_WIDTH * 0.5,
			sr.size.y * WORLD_HEIGHT * 0.5,
			0.1
		)
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		pm.emission_box_extents = ext
		particles.position.x += (sr.position.x - 0.5) * WORLD_WIDTH
		particles.position.y += (sr.position.y - 0.5) * WORLD_HEIGHT
	particles.process_material = pm

	var quad = QuadMesh.new()
	var qmat = StandardMaterial3D.new()
	qmat.albedo_texture = config.texture
	qmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	qmat.albedo_color = config.modulate
	quad.material = qmat
	particles.draw_pass_1 = quad

	if not _quads_node:
		_quads_node = Node3D.new()
		_quads_node.name = "BackgroundQuads"
		var vp = get_node_or_null("SubViewportContainer/SubViewport")
		if vp:
			vp.add_child(_quads_node)

	_quads_node.add_child(particles)

	var entry = _ParticleEntry.new()
	entry.config = config
	entry.particles = particles
	_particles.append(entry)
	return _particles.size() - 1

func remove_particle(index: int):
	if index < 0 or index >= _particles.size():
		return
	var entry = _particles[index]
	if is_instance_valid(entry.particles):
		entry.particles.queue_free()
	_particles.remove_at(index)

func get_particle_count() -> int:
	return _particles.size()

func clear_all():
	for q in _quads:
		_kill_entry_tweens(q)
		if is_instance_valid(q.mesh):
			q.mesh.queue_free()
	_quads.clear()
	for p in _particles:
		if is_instance_valid(p.particles):
			p.particles.queue_free()
	_particles.clear()

# ──  Tween Infrastructure  ──

func _kill_entry_tweens(entry: _QuadEntry):
	for info in entry.active_tweens:
		var tw: Tween = info.get("tween")
		if tw and tw.is_valid():
			tw.kill()
	entry.active_tweens.clear()

func _kill_all_tweens():
	for q in _quads:
		_kill_entry_tweens(q)
	if _transition_tween and _transition_tween.is_valid():
		_transition_tween.kill()

func _tween_property(entry: _QuadEntry, getter: Callable, setter: Callable, target_value, duration: float, property: String = ""):
	if duration <= 0.0:
		setter.call(target_value)
		return

	_kill_entry_tween_for_property(entry, property)

	var tween = create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_EXPO)
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_method(
		func(v): setter.call(v),
		getter.call(),
		target_value,
		duration
	)
	tween.finished.connect(_on_tween_done.bind(entry, tween, property))
	entry.active_tweens.append({"tween": tween, "property": property})

func _kill_entry_tween_for_property(entry: _QuadEntry, property: String):
	if property == "":
		return
	var to_remove: Array[int] = []
	for i in range(entry.active_tweens.size()):
		var info = entry.active_tweens[i]
		if info.get("property") == property:
			var tw: Tween = info.get("tween")
			if tw and tw.is_valid():
				tw.kill()
			to_remove.append(i)
	to_remove.reverse()
	for idx in to_remove:
		entry.active_tweens.remove_at(idx)

func _on_tween_done(entry: _QuadEntry, tween: Tween, _property: String):
	for i in range(entry.active_tweens.size() - 1, -1, -1):
		var info = entry.active_tweens[i]
		if info.get("tween") == tween:
			entry.active_tweens.remove_at(i)
			break

# ──  Single Quad Control  ──

func set_quad_position(index: int, pos: Vector3, duration: float = 0.0):
	if index < 0 or index >= _quads.size(): return
	var entry = _quads[index]
	_tween_property(entry,
		func(): return entry.mesh.position,
		func(v): entry.mesh.position = v; entry.config.position = v,
		pos, duration, "position")

func set_quad_rotation(index: int, rot: Vector3, duration: float = 0.0):
	if index < 0 or index >= _quads.size(): return
	var entry = _quads[index]
	_tween_property(entry,
		func(): return entry.mesh.rotation_degrees,
		func(v): entry.mesh.rotation_degrees = v; entry.config.rotation = v,
		rot, duration, "rotation")

func set_quad_size(index: int, sz: Vector2):
	if index < 0 or index >= _quads.size(): return
	var entry = _quads[index]
	var qm: QuadMesh = entry.mesh.mesh
	if qm:
		qm.size = sz
	entry.config.size = sz

func set_quad_scroll(index: int, scroll: Vector3, duration: float = 0.0):
	if index < 0 or index >= _quads.size(): return
	var entry = _quads[index]
	_tween_property(entry,
		func(): return entry.config.scroll,
		func(v): entry.config.scroll = v,
		scroll, duration, "scroll")

func set_quad_color(index: int, clr: Color, duration: float = 0.0):
	if index < 0 or index >= _quads.size(): return
	var entry = _quads[index]
	_tween_property(entry,
		func(): return entry.material.albedo_color,
		func(v):
			entry.material.albedo_color = v
			entry.config.color = v,
		clr, duration, "color")

func set_quad_texture(index: int, tex: Texture2D):
	if index < 0 or index >= _quads.size(): return
	var entry = _quads[index]
	entry.material.albedo_texture = tex
	entry.config.texture = tex

func set_quad_visible(index: int, should_show: bool, duration: float = 0.0):
	if index < 0 or index >= _quads.size(): return
	var entry = _quads[index]
	if duration <= 0.0:
		entry.mesh.visible = should_show
		return
	if should_show:
		entry.mesh.modulate.a = 0.0
		entry.mesh.visible = true
		_tween_property(entry,
			func(): return entry.mesh.modulate.a,
			func(v): entry.mesh.modulate.a = v,
			1.0, duration, "visible")
	else:
		_tween_property(entry,
			func(): return entry.mesh.modulate.a,
			func(v):
				entry.mesh.modulate.a = v
				if v <= 0.01:
					entry.mesh.visible = false,
			0.0, duration, "visible")

func set_quad_tile(index: int, tile: Vector2):
	if index < 0 or index >= _quads.size(): return
	var entry = _quads[index]
	entry.material.uv1_scale = Vector3(tile.x, tile.y, 1.0)
	entry.config.tile = tile

func fade_quad(index: int, target, duration: float = 0.5):
	if index < 0 or index >= _quads.size(): return
	var entry = _quads[index]
	if target is Color:
		set_quad_color(index, target, duration)
	elif target is float or target is int:
		var c = entry.config.color
		c.a = float(target)
		set_quad_color(index, c, duration)

# ──  Global Control  ──

func set_fog(color: Color, density: float, depth_begin: float, depth_end: float, duration: float = 0.0):
	if not _world_env or not _world_env.environment:
		return
	if duration <= 0.0:
		_world_env.environment.fog_light_color = color
		_world_env.environment.fog_density = density
		_world_env.environment.fog_depth_begin = depth_begin
		_world_env.environment.fog_depth_end = depth_end
		return

	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_EXPO)
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_method(
		func(v): _world_env.environment.fog_light_color = v,
		_world_env.environment.fog_light_color, color, duration)
	tween.tween_method(
		func(v): _world_env.environment.fog_density = v,
		_world_env.environment.fog_density, density, duration)
	tween.tween_method(
		func(v): _world_env.environment.fog_depth_begin = v,
		_world_env.environment.fog_depth_begin, depth_begin, duration)
	tween.tween_method(
		func(v): _world_env.environment.fog_depth_end = v,
		_world_env.environment.fog_depth_end, depth_end, duration)

func shake(intensity: float, duration: float):
	if not _camera:
		return
	_shake_intensity = intensity
	_shake_duration = duration
	_shake_elapsed = 0.0
	_shake_active = true

func set_front_texture(texture: Texture2D, duration: float = 0.0):
	if not _foreground_rect:
		return
	if duration <= 0.0:
		_foreground_rect.texture = texture
		return

	var tween = create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(_foreground_rect, "modulate:a", 0.0, duration * 0.5)
	tween.tween_callback(func():
		_foreground_rect.texture = texture
	)
	tween.tween_property(_foreground_rect, "modulate:a", 1.0, duration * 0.5)

func fade_in(duration: float = 1.5):
	if not _viewport_container:
		return
	_viewport_container.modulate.a = 0.0
	var tween = create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(_viewport_container, "modulate:a", 1.0, duration)

func fade_out(duration: float = 1.5):
	if not _viewport_container:
		return
	var tween = create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(_viewport_container, "modulate:a", 0.0, duration)

# ──  Preset Loading & Transition  ──

func load_preset(data: Resource):
	if not data:
		clear_all()
		return

	clear_all()

	for quad in data.quads:
		var cfg: Dictionary = {
			"pos": quad.position,
			"rot": quad.rotation,
			"size": quad.size,
			"tile": quad.tile,
			"scroll": quad.scroll,
			"color": quad.color,
		}
		add_quad(quad.texture, cfg)

	for pc in data.particles:
		add_particle(pc)

	set_fog(data.fog_color, data.fog_density, data.fog_depth_begin, data.fog_depth_end)
	set_front_texture(data.front_texture)

func transition_to(data: Resource, duration: float = 1.5):
	if not data:
		return
	if duration <= 0.0:
		load_preset(data)
		return

	if _transition_tween and _transition_tween.is_valid():
		_transition_tween.kill()
		for entry in _old_quads:
			if is_instance_valid(entry.mesh):
				entry.mesh.queue_free()
		_old_quads.clear()
		if _old_quads_node:
			_old_quads_node.queue_free()
		_old_quads_node = null

	_old_quads = _quads.duplicate(true)
	_old_quads_node = _quads_node

	_quads_node = Node3D.new()
	_quads_node.name = "BackgroundQuads"
	get_node("SubViewportContainer/SubViewport").add_child(_quads_node)
	_quads.clear()

	load_preset(data)

	for entry in _quads:
		entry.mesh.modulate.a = 0.0

	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)

	for entry in _old_quads:
		tween.tween_property(entry.mesh, "modulate:a", 0.0, duration)
	for entry in _quads:
		tween.tween_property(entry.mesh, "modulate:a", 1.0, duration)

	tween.finished.connect(_on_transition_done)
	_transition_tween = tween

func _on_transition_done():
	for entry in _old_quads:
		if is_instance_valid(entry.mesh):
			entry.mesh.queue_free()
	_old_quads.clear()
	if _old_quads_node:
		_old_quads_node.queue_free()
	_old_quads_node = null
	_transition_tween = null

# ──  Process  ──

func _process(delta: float):
	if _paused or Engine.is_editor_hint():
		return

	_update_shake(delta)
	_update_scroll(delta)

func _update_scroll(delta: float):
	for entry in _quads:
		if not entry.material:
			continue
		entry.material.uv1_offset += entry.config.scroll * delta

func _update_shake(delta: float):
	if not _shake_active or not _camera:
		return
	_shake_elapsed += delta
	if _shake_elapsed >= _shake_duration:
		_camera.position = CAMERA_REST_POSITION
		_shake_active = false
		return

	var t = _shake_elapsed / _shake_duration
	var decay = ease(1.0 - t, -2.0)
	var intensity = _shake_intensity * decay
	var shake_offset = Vector2(
		(randf() * 2.0 - 1.0) * intensity * WORLD_UNIT_PER_PIXEL,
		(randf() * 2.0 - 1.0) * intensity * WORLD_UNIT_PER_PIXEL
	)
	_camera.position = CAMERA_REST_POSITION + Vector3(shake_offset.x, shake_offset.y, 0.0)

# ──  Game State  ──

func reset():
	clear_all()
	_paused = false
	_shake_active = false
	if _viewport_container:
		_viewport_container.modulate.a = 1.0

func _on_game_state_changed(old: int, new: int):
	if new == GameManager.AppState.PAUSED:
		_paused = true
	elif old == GameManager.AppState.PAUSED and new != GameManager.AppState.TRANSITIONING:
		_paused = false
	elif old == GameManager.AppState.TRANSITIONING and new == GameManager.AppState.PLAYING:
		_paused = false
