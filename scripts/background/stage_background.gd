extends CanvasLayer
class_name StageBackground

const LayerScrollShader = preload("res://shader/bg_layer_scroll.gdshader")
const GroundShader = preload("res://shader/Ground.gdshader")
const OverlayShader = preload("res://shader/bg_overlay.gdshader")

@onready var _camera: Camera3D = %Camera3D
@onready var _sky_mesh: MeshInstance3D = %SkyMesh
@onready var _layer_container: Node3D = %LayerContainer
@onready var _ground_mesh: MeshInstance3D = %GroundMesh
@onready var _world_env: WorldEnvironment = %WorldEnvironment
@onready var _camera_ctrl: BgCameraController = %BgCameraController
var _accumulated_time: float = 0.0
var _time_scale: float = 1.0
var _dynamic_layers: Array[MeshInstance3D] = []
var _snapshots: Dictionary = {}
var _screen_fx: ColorRect = null

func _ready():
	_camera_ctrl.setup(_camera)
	_setup_screen_fx()

func _setup_screen_fx():
	_screen_fx = ColorRect.new()
	_screen_fx.name = "ScreenFX"
	_screen_fx.set_anchors_preset(Control.PRESET_FULL_RECT)
	_screen_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen_fx.color = Color.TRANSPARENT
	var mat = ShaderMaterial.new()
	mat.shader = OverlayShader
	mat.set_shader_parameter("vignette_strength", 0.0)
	mat.set_shader_parameter("vignette_color", Color.BLACK)
	mat.set_shader_parameter("chromatic_strength", 0.0)
	mat.set_shader_parameter("scanline_strength", 0.0)
	mat.set_shader_parameter("scanline_color", Color.BLACK)
	mat.set_shader_parameter("overlay_color", Color.TRANSPARENT)
	_screen_fx.material = mat
	add_child(_screen_fx)

func reset():
	clear_layers()
	_clear_sky()
	_clear_ground()
	reset_time()
	_snapshots.clear()
	_time_scale = 1.0

# ── 时间缩放 ──

func set_time_scale(p_scale: float):
	_time_scale = p_scale

func get_time_scale() -> float:
	return _time_scale

# ── 快照系统 ──

func save_snapshot(snap_name: String):
	var snap = {}
	snap["fog_color"] = get_fog_color()
	snap["fog_density"] = get_fog_density()
	snap["fog_height_density"] = get_fog_height_density()
	snap["fog_depth_begin"] = get_fog_depth_begin()
	snap["fog_depth_end"] = get_fog_depth_end()
	snap["camera_fov"] = get_camera_fov()
	snap["camera_position"] = get_camera_position()
	snap["camera_rotation"] = get_camera_rotation_degrees()
	snap["ground_scroll"] = get_ground_scroll()
	snap["ground_grid_scale"] = get_ground_grid_scale()
	snap["ground_line_width"] = get_ground_line_width()
	snap["ground_grid_color"] = get_ground_grid_color()
	snap["ground_tint"] = get_ground_tint()
	snap["sky_scroll"] = get_sky_scroll()
	snap["sky_tint"] = get_sky_tint()
	snap["time_scale"] = _time_scale
	snap["fov_stretch"] = get_fov_stretch()
	snap["roll"] = get_roll()
	snap["camera_speed_mult"] = get_camera_speed_mult()
	snap["ambient_light"] = get_ambient_light()
	snap["screen_vignette"] = get_vignette()
	snap["screen_overlay"] = get_overlay_color()
	_snapshots[snap_name] = snap

func load_snapshot(snap_name: String):
	if not _snapshots.has(snap_name):
		return
	var snap = _snapshots[snap_name]
	for key in snap:
		_apply_snapshot_property(key, snap[key])

func _apply_snapshot_property(key: String, value):
	match key:
		"fog_color": set_fog_color(value)
		"fog_density": set_fog_density(value)
		"fog_height_density": set_fog_height_density(value)
		"fog_depth_begin": set_fog_depth_begin(value)
		"fog_depth_end": set_fog_depth_end(value)
		"camera_fov": set_camera_fov(value)
		"camera_position": set_camera_position(value)
		"camera_rotation": set_camera_rotation_degrees(value)
		"ground_scroll": set_ground_scroll(value)
		"ground_grid_scale": set_ground_grid_scale(value)
		"ground_line_width": set_ground_line_width(value)
		"ground_grid_color": set_ground_grid_color(value)
		"ground_tint": set_ground_tint(value)
		"sky_scroll": set_sky_scroll(value)
		"sky_tint": set_sky_tint(value)
		"time_scale": set_time_scale(value)
		"fov_stretch": set_fov_stretch(value)
		"roll": set_roll(value)
		"camera_speed_mult": set_camera_speed_mult(value)
		"ambient_light": set_ambient_light(value)
		"screen_vignette": set_vignette(value)
		"screen_overlay": set_overlay_color(value)

func get_snapshot_property_value(key: String):
	match key:
		"fog_color": return get_fog_color()
		"fog_density": return get_fog_density()
		"fog_height_density": return get_fog_height_density()
		"fog_depth_begin": return get_fog_depth_begin()
		"fog_depth_end": return get_fog_depth_end()
		"camera_fov": return get_camera_fov()
		"camera_position": return get_camera_position()
		"camera_rotation": return get_camera_rotation_degrees()
		"ground_scroll": return get_ground_scroll()
		"ground_grid_scale": return get_ground_grid_scale()
		"ground_line_width": return get_ground_line_width()
		"ground_grid_color": return get_ground_grid_color()
		"ground_tint": return get_ground_tint()
		"sky_scroll": return get_sky_scroll()
		"sky_tint": return get_sky_tint()
		"time_scale": return _time_scale
		"fov_stretch": return get_fov_stretch()
		"roll": return get_roll()
		"camera_speed_mult": return get_camera_speed_mult()
		"ambient_light": return get_ambient_light()
		"screen_vignette": return get_vignette()
		"screen_overlay": return get_overlay_color()
	return null

func has_snapshot(snap_name: String) -> bool:
	return _snapshots.has(snap_name)

func get_snapshot_keys() -> Array:
	return _snapshots.keys()

# ── 层管理 ──

func add_scroll_layer(texture: Texture2D, scroll_speed: Vector2 = Vector2(0, -0.1), z_pos: float = 10.0, quad_scale: float = 2.0, tint: Color = Color.WHITE, blend_mode: int = 0) -> int:
	var mesh_layer = _build_scroll_layer(texture, scroll_speed, z_pos, quad_scale, tint, blend_mode)
	_layer_container.add_child(mesh_layer)
	_dynamic_layers.append(mesh_layer)
	return _dynamic_layers.size() - 1

func set_layer_scroll(layer_index: int, scroll: Vector2):
	if not _valid_layer(layer_index):
		return
	_dynamic_layers[layer_index].material_override.set_shader_parameter("scroll_speed", scroll)

func get_layer_scroll(layer_index: int) -> Vector2:
	if not _valid_layer(layer_index):
		return Vector2.ZERO
	return _dynamic_layers[layer_index].material_override.get_shader_parameter("scroll_speed")

func set_layer_tint(layer_index: int, tint: Color):
	if not _valid_layer(layer_index):
		return
	_dynamic_layers[layer_index].material_override.set_shader_parameter("tint", tint)

func get_layer_tint(layer_index: int) -> Color:
	if not _valid_layer(layer_index):
		return Color.WHITE
	return _dynamic_layers[layer_index].material_override.get_shader_parameter("tint")

func set_layer_z_pos(layer_index: int, z: float):
	if not _valid_layer(layer_index):
		return
	var mesh_layer = _dynamic_layers[layer_index]
	mesh_layer.position.z = z

func get_layer_z_pos(layer_index: int) -> float:
	if not _valid_layer(layer_index):
		return 0.0
	return _dynamic_layers[layer_index].position.z

func set_layer_scale(layer_index: int, s: float):
	if not _valid_layer(layer_index):
		return
	var mesh_layer = _dynamic_layers[layer_index]
	var quad: QuadMesh = mesh_layer.mesh
	quad.size = Vector2(36, 27) * s

func get_layer_scale(layer_index: int) -> float:
	if not _valid_layer(layer_index):
		return 1.0
	var mesh_layer = _dynamic_layers[layer_index]
	var quad: QuadMesh = mesh_layer.mesh
	return quad.size.x / 36.0

func set_layer_blend_strength(layer_index: int, strength: float):
	if not _valid_layer(layer_index):
		return
	_dynamic_layers[layer_index].material_override.set_shader_parameter("blend_strength", strength)

func get_layer_blend_strength(layer_index: int) -> float:
	if not _valid_layer(layer_index):
		return 0.0
	return _dynamic_layers[layer_index].material_override.get_shader_parameter("blend_strength")

func set_layer_visible(layer_index: int, should_show: bool):
	if not _valid_layer(layer_index):
		return
	_dynamic_layers[layer_index].visible = should_show

func remove_layer(layer_index: int):
	if not _valid_layer(layer_index):
		return
	var mesh_layer = _dynamic_layers[layer_index]
	if is_instance_valid(mesh_layer):
		mesh_layer.queue_free()
	_dynamic_layers.remove_at(layer_index)

func clear_layers():
	for mesh_layer in _dynamic_layers:
		if is_instance_valid(mesh_layer):
			mesh_layer.queue_free()
	_dynamic_layers.clear()
	for child in _layer_container.get_children():
		child.queue_free()

func get_layer_count() -> int:
	return _dynamic_layers.size()

func _valid_layer(index: int) -> bool:
	return index >= 0 and index < _dynamic_layers.size() and is_instance_valid(_dynamic_layers[index]) and _dynamic_layers[index].material_override

# ── 天空 ──

func set_sky(texture: Texture2D, scroll: Vector2 = Vector2(0, -0.02), quad_scale: float = 3.0, tint: Color = Color.WHITE):
	var mesh_layer = _build_scroll_layer(texture, scroll, 30.0, quad_scale, tint, 0)
	_sky_mesh.replace_by(mesh_layer)
	_sky_mesh = mesh_layer

func set_sky_scroll(scroll: Vector2):
	if _sky_mesh and _sky_mesh.material_override:
		_sky_mesh.material_override.set_shader_parameter("scroll_speed", scroll)

func get_sky_scroll() -> Vector2:
	if _sky_mesh and _sky_mesh.material_override:
		return _sky_mesh.material_override.get_shader_parameter("scroll_speed")
	return Vector2.ZERO

func set_sky_tint(tint: Color):
	if _sky_mesh and _sky_mesh.material_override:
		_sky_mesh.material_override.set_shader_parameter("tint", tint)

func get_sky_tint() -> Color:
	if _sky_mesh and _sky_mesh.material_override:
		return _sky_mesh.material_override.get_shader_parameter("tint")
	return Color.WHITE

func _clear_sky():
	if _sky_mesh:
		_sky_mesh.mesh = null
		_sky_mesh.material_override = null

# ── 地面 ──

func set_ground(texture: Texture2D, scroll: Vector2 = Vector2(0, -0.2), grid_scale: float = 20.0, line_width: float = 0.03, grid_color: Color = Color(0.3, 0.5, 1.0, 0.0), tint: Color = Color.WHITE):
	var mat = ShaderMaterial.new()
	mat.shader = GroundShader
	mat.set_shader_parameter("base_texture", texture)
	mat.set_shader_parameter("scroll_speed", scroll)
	mat.set_shader_parameter("grid_scale", grid_scale)
	mat.set_shader_parameter("grid_line_width", line_width)
	mat.set_shader_parameter("grid_color", grid_color)
	mat.set_shader_parameter("base_tint", tint)
	_ground_mesh.material_override = mat
	_camera_ctrl._push_ground_params()

func set_ground_scroll(scroll: Vector2):
	_set_ground_param("scroll_speed", scroll)

func get_ground_scroll() -> Vector2:
	return _get_ground_param("scroll_speed", Vector2.ZERO)

func set_ground_grid_scale(value: float):
	_set_ground_param("grid_scale", value)

func get_ground_grid_scale() -> float:
	return _get_ground_param("grid_scale", 20.0)

func set_ground_line_width(value: float):
	_set_ground_param("grid_line_width", value)

func get_ground_line_width() -> float:
	return _get_ground_param("grid_line_width", 0.03)

func set_ground_grid_color(value: Color):
	_set_ground_param("grid_color", value)

func get_ground_grid_color() -> Color:
	return _get_ground_param("grid_color", Color(0.3, 0.5, 1.0, 0.0))

func set_ground_tint(value: Color):
	_set_ground_param("base_tint", value)

func get_ground_tint() -> Color:
	return _get_ground_param("base_tint", Color.WHITE)

func _clear_ground():
	if _ground_mesh:
		_ground_mesh.material_override = null

func _set_ground_param(param_name: String, value):
	if _ground_mesh and _ground_mesh.material_override:
		_ground_mesh.material_override.set_shader_parameter(param_name, value)

func _get_ground_param(param_name: String, default_val):
	if _ground_mesh and _ground_mesh.material_override:
		return _ground_mesh.material_override.get_shader_parameter(param_name)
	return default_val

# ── 环境 / 雾 ──

func set_fog(color: Color = Color(0.49, 0.42, 0.67, 1), density: float = 1.0, height_density: float = 0.5, depth_begin: float = 3.0, depth_end: float = 35.0, bg_color: Color = Color(0.15, 0.15, 0.31, 1)):
	if not _world_env.environment:
		return
	var env = _world_env.environment
	env.fog_light_color = color
	env.fog_density = density
	env.fog_height_density = height_density
	env.fog_depth_begin = depth_begin
	env.fog_depth_end = depth_end
	env.background_color = bg_color

func set_fog_color(color: Color):
	if _world_env.environment:
		_world_env.environment.fog_light_color = color

func get_fog_color() -> Color:
	if _world_env.environment:
		return _world_env.environment.fog_light_color
	return Color.BLACK

func set_fog_density(density: float):
	if _world_env.environment:
		_world_env.environment.fog_density = density

func get_fog_density() -> float:
	if _world_env.environment:
		return _world_env.environment.fog_density
	return 1.0

func set_fog_height_density(value: float):
	if _world_env.environment:
		_world_env.environment.fog_height_density = value

func get_fog_height_density() -> float:
	if _world_env.environment:
		return _world_env.environment.fog_height_density
	return 0.5

func set_fog_depth_begin(value: float):
	if _world_env.environment:
		_world_env.environment.fog_depth_begin = value

func get_fog_depth_begin() -> float:
	if _world_env.environment:
		return _world_env.environment.fog_depth_begin
	return 3.0

func set_fog_depth_end(value: float):
	if _world_env.environment:
		_world_env.environment.fog_depth_end = value

func get_fog_depth_end() -> float:
	if _world_env.environment:
		return _world_env.environment.fog_depth_end
	return 35.0

# ── 环境光 ──

func set_ambient_light(color: Color):
	if _world_env.environment:
		_world_env.environment.ambient_light_color = color

func get_ambient_light() -> Color:
	if _world_env.environment:
		return _world_env.environment.ambient_light_color
	return Color.BLACK

# ── 相机 ──

func setup_camera():
	_camera_ctrl.setup(_camera)

func trigger_shake(amplitude: float = 2.0, decay: float = 4.0):
	_camera_ctrl.trigger_shake(amplitude, decay)

func reset_camera():
	_camera_ctrl.reset_camera()

func set_camera_position(pos: Vector3):
	_camera_ctrl.set_camera_position(pos)

func get_camera_position() -> Vector3:
	return _camera_ctrl.get_camera_position()

func set_camera_rotation_degrees(rot: Vector3):
	_camera_ctrl.set_camera_rotation_degrees(rot)

func get_camera_rotation_degrees() -> Vector3:
	return _camera_ctrl.get_camera_rotation_degrees()

func set_camera_fov(fov: float):
	_camera_ctrl.set_camera_fov(fov)

func get_camera_fov() -> float:
	return _camera_ctrl.get_camera_fov()

func set_fov_stretch(value: float):
	_camera_ctrl.set_fov_stretch(value)

func get_fov_stretch() -> float:
	return _camera_ctrl.get_fov_stretch()

func set_roll(value: float):
	_camera_ctrl.set_roll(value)

func get_roll() -> float:
	return _camera_ctrl.get_roll()

func set_camera_speed_mult(value: float):
	_camera_ctrl.set_camera_speed_mult(value)

func get_camera_speed_mult() -> float:
	return _camera_ctrl.get_camera_speed_mult()

# ── 屏幕后处理 ──

func set_vignette(strength: float, color: Color = Color.BLACK):
	if not _screen_fx:
		return
	var mat: ShaderMaterial = _screen_fx.material
	mat.set_shader_parameter("vignette_strength", strength)
	mat.set_shader_parameter("vignette_color", color)

func get_vignette() -> float:
	if not _screen_fx:
		return 0.0
	return _screen_fx.material.get_shader_parameter("vignette_strength")

func set_overlay_color(color: Color):
	if not _screen_fx:
		return
	_screen_fx.material.set_shader_parameter("overlay_color", color)

func get_overlay_color() -> Color:
	if not _screen_fx:
		return Color.TRANSPARENT
	return _screen_fx.material.get_shader_parameter("overlay_color")

func screen_flash(color: Color, hold_duration: float = 0.1):
	if not _screen_fx:
		return
	_screen_fx.material.set_shader_parameter("overlay_color", color)
	if hold_duration > 0:
		get_tree().create_timer(hold_duration).timeout.connect(
			func(): _screen_fx.material.set_shader_parameter("overlay_color", Color.TRANSPARENT)
		)

# ── 时间轴 ──

func reset_time():
	_accumulated_time = 0.0

# ── 内部 ──

func _build_scroll_layer(texture: Texture2D, scroll_speed: Vector2, z_pos: float, quad_scale: float, tint: Color, blend_mode: int = 0) -> MeshInstance3D:
	var mesh_node = MeshInstance3D.new()
	var quad = QuadMesh.new()
	quad.size = Vector2(36, 27) * quad_scale
	mesh_node.mesh = quad
	mesh_node.rotation_degrees.x = -90
	var mat = ShaderMaterial.new()
	mat.shader = LayerScrollShader
	mat.set_shader_parameter("layer_texture", texture)
	mat.set_shader_parameter("scroll_speed", scroll_speed)
	mat.set_shader_parameter("tint", tint)
	mat.set_shader_parameter("blend_mode", blend_mode)
	mat.set_shader_parameter("blend_strength", 0.0)
	mesh_node.material_override = mat
	mesh_node.position = Vector3(0, -1, z_pos)
	return mesh_node

func _process(delta):
	if GameManager.current_state == GameManager.AppState.PLAYING:
		_accumulated_time += delta * _time_scale
		_update_all_shader_time()

func _update_all_shader_time():
	var t = _accumulated_time
	if _sky_mesh and _sky_mesh.material_override:
		_sky_mesh.material_override.set_shader_parameter("u_custom_time", t)
	for child in _layer_container.get_children():
		if child is MeshInstance3D and child.material_override:
			child.material_override.set_shader_parameter("u_custom_time", t)
	if _ground_mesh and _ground_mesh.material_override:
		_ground_mesh.material_override.set_shader_parameter("u_custom_time", t)
