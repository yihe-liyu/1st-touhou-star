extends CanvasLayer
class_name StageBackground

var _accumulated_time: float = 0.0

const LayerScrollShader = preload("res://shader/bg_layer_scroll.gdshader")
const GroundShader = preload("res://shader/Ground.gdshader")

@onready var _camera: Camera3D = %Camera3D
@onready var _sky_mesh: MeshInstance3D = %SkyMesh
@onready var _layer_container: Node3D = %LayerContainer
@onready var _ground_mesh: MeshInstance3D = %GroundMesh
@onready var _world_env: WorldEnvironment = %WorldEnvironment
@onready var _camera_ctrl: BgCameraController = %BgCameraController

var _dynamic_layers: Array[MeshInstance3D] = []

func _ready():
	_camera_ctrl.setup(_camera)

func reset():
	clear_layers()
	_clear_sky()
	_clear_ground()
	reset_time()

# ── 层管理 ──

func add_scroll_layer(texture: Texture2D, scroll_speed: Vector2 = Vector2(0, -0.1), z_pos: float = 10.0, quad_scale: float = 2.0, tint: Color = Color.WHITE) -> int:
	var mesh_layer = _build_scroll_layer(texture, scroll_speed, z_pos, quad_scale, tint)
	_layer_container.add_child(mesh_layer)
	_dynamic_layers.append(mesh_layer)
	return _dynamic_layers.size() - 1

func set_layer_scroll(layer_index: int, scroll: Vector2):
	if layer_index < 0 or layer_index >= _dynamic_layers.size():
		return
	var mesh_layer = _dynamic_layers[layer_index]
	if is_instance_valid(mesh_layer) and mesh_layer.material_override:
		mesh_layer.material_override.set_shader_parameter("scroll_speed", scroll)

func get_layer_scroll(layer_index: int) -> Vector2:
	if layer_index < 0 or layer_index >= _dynamic_layers.size():
		return Vector2.ZERO
	var mesh_layer = _dynamic_layers[layer_index]
	if is_instance_valid(mesh_layer) and mesh_layer.material_override:
		return mesh_layer.material_override.get_shader_parameter("scroll_speed")
	return Vector2.ZERO

func set_layer_tint(layer_index: int, tint: Color):
	if layer_index < 0 or layer_index >= _dynamic_layers.size():
		return
	var mesh_layer = _dynamic_layers[layer_index]
	if is_instance_valid(mesh_layer) and mesh_layer.material_override:
		mesh_layer.material_override.set_shader_parameter("tint", tint)

func get_layer_tint(layer_index: int) -> Color:
	if layer_index < 0 or layer_index >= _dynamic_layers.size():
		return Color.WHITE
	var mesh_layer = _dynamic_layers[layer_index]
	if is_instance_valid(mesh_layer) and mesh_layer.material_override:
		return mesh_layer.material_override.get_shader_parameter("tint")
	return Color.WHITE

func set_layer_visible(layer_index: int, should_show: bool):
	if layer_index < 0 or layer_index >= _dynamic_layers.size():
		return
	var mesh_layer = _dynamic_layers[layer_index]
	if is_instance_valid(mesh_layer):
		mesh_layer.visible = should_show

func remove_layer(layer_index: int):
	if layer_index < 0 or layer_index >= _dynamic_layers.size():
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

# ── 天空 ──

func set_sky(texture: Texture2D, scroll: Vector2 = Vector2(0, -0.02), quad_scale: float = 3.0, tint: Color = Color.WHITE):
	var mesh_layer = _build_scroll_layer(texture, scroll, 30.0, quad_scale, tint)
	_sky_mesh.replace_by(mesh_layer)
	_sky_mesh = mesh_layer

func set_sky_scroll(scroll: Vector2):
	if _sky_mesh and _sky_mesh.material_override:
		_sky_mesh.material_override.set_shader_parameter("scroll_speed", scroll)

func get_sky_scroll() -> Vector2:
	if _sky_mesh and _sky_mesh.material_override:
		return _sky_mesh.material_override.get_shader_parameter("scroll_speed")
	return Vector2.ZERO

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

func set_ground_scroll(scroll: Vector2):
	set_ground_param("scroll_speed", scroll)

func get_ground_scroll() -> Vector2:
	if _ground_mesh and _ground_mesh.material_override:
		return _ground_mesh.material_override.get_shader_parameter("scroll_speed")
	return Vector2.ZERO

func _clear_ground():
	if _ground_mesh:
		_ground_mesh.material_override = null

func set_ground_param(param_name: String, value):
	if _ground_mesh and _ground_mesh.material_override:
		_ground_mesh.material_override.set_shader_parameter(param_name, value)

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
	if not _world_env.environment: return
	_world_env.environment.fog_light_color = color

func get_fog_color() -> Color:
	if _world_env.environment: return _world_env.environment.fog_light_color
	return Color.BLACK

func set_fog_density(density: float):
	if not _world_env.environment: return
	_world_env.environment.fog_density = density

func get_fog_density() -> float:
	if _world_env.environment: return _world_env.environment.fog_density
	return 1.0

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

# ── 时间轴 ──

func reset_time():
	_accumulated_time = 0.0

# ── 内部 ──

func _build_scroll_layer(texture: Texture2D, scroll_speed: Vector2, z_pos: float, quad_scale: float, tint: Color) -> MeshInstance3D:
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
	mesh_node.material_override = mat
	mesh_node.position = Vector3(0, -1, z_pos)
	return mesh_node

func _process(delta):
	if GameManager.current_state == GameManager.AppState.PLAYING:
		_accumulated_time += delta
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
