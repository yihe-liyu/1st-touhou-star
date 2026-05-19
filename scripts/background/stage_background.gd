extends CanvasLayer
class_name StageBackground

const LayerScrollShader = preload("res://shader/bg_layer_scroll.gdshader")
const GroundShader = preload("res://shader/Ground.gdshader")

## 关卡背景配置数据（StageBackgroundData 资源）
@export var background_data: StageBackgroundData

@onready var _camera: Camera3D = %Camera3D
@onready var _sky_mesh: MeshInstance3D = %SkyMesh
@onready var _layer_container: Node3D = %LayerContainer
@onready var _ground_mesh: MeshInstance3D = %GroundMesh
@onready var _world_env: WorldEnvironment = %WorldEnvironment
@onready var _camera_ctrl: BgCameraController = %BgCameraController

func _ready():
	if not background_data:
		return
	_apply_data()
	if background_data.camera_config:
		_camera_ctrl.setup(background_data.camera_config, _camera)

func _make_flat_quad(scale_mult: float = 1.0) -> QuadMesh:
	var q = QuadMesh.new()
	q.size = Vector2(36, 27) * scale_mult
	return q

func _spawn_layer(cfg: BgLayerConfig) -> MeshInstance3D:
	var mesh_node = MeshInstance3D.new()
	mesh_node.mesh = _make_flat_quad(cfg.scale)
	mesh_node.rotation_degrees.x = -90
	var mat = ShaderMaterial.new()
	mat.shader = LayerScrollShader
	mat.set_shader_parameter("layer_texture", cfg.texture)
	mat.set_shader_parameter("scroll_speed", cfg.scroll_speed)
	mat.set_shader_parameter("tint", cfg.tint)
	mesh_node.material_override = mat
	mesh_node.position = Vector3(0, -1, cfg.z_position)
	return mesh_node

func _apply_data():
	var bd = background_data

	if bd.sky_texture:
		var sky_cfg = BgLayerConfig.new()
		sky_cfg.texture = bd.sky_texture
		sky_cfg.scroll_speed = bd.sky_scroll
		sky_cfg.scale = bd.sky_scale
		sky_cfg.tint = bd.sky_tint
		sky_cfg.z_position = 30.0
		var spawned = _spawn_layer(sky_cfg)
		spawned.name = "SkyLayer"
		_sky_mesh.replace_by(spawned)
		_sky_mesh = spawned

	for cfg in bd.layers:
		if not cfg.texture:
			continue
		_layer_container.add_child(_spawn_layer(cfg))

	if bd.ground_texture:
		var mat = ShaderMaterial.new()
		mat.shader = GroundShader
		mat.set_shader_parameter("base_texture", bd.ground_texture)
		mat.set_shader_parameter("scroll_speed", bd.ground_scroll)
		mat.set_shader_parameter("grid_scale", bd.ground_grid_scale)
		mat.set_shader_parameter("grid_line_width", bd.ground_grid_line_width)
		mat.set_shader_parameter("grid_color", bd.ground_grid_color)
		mat.set_shader_parameter("base_tint", bd.ground_tint)
		_ground_mesh.material_override = mat

	if _world_env.environment:
		var env = _world_env.environment
		env.fog_light_color = bd.fog_color
		env.fog_density = bd.fog_density
		env.fog_height_density = bd.fog_height_density
		env.fog_depth_begin = bd.fog_depth_begin
		env.fog_depth_end = bd.fog_depth_end
		env.background_color = bd.background_color

func trigger_shake(amplitude: float = 2.0, decay: float = 4.0):
	_camera_ctrl.trigger_shake(amplitude, decay)

func set_ground_param(param_name: String, value):
	if _ground_mesh and _ground_mesh.material_override:
		_ground_mesh.material_override.set_shader_parameter(param_name, value)
