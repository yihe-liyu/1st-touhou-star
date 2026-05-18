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

func _apply_data():
	var bd = background_data

	if bd.sky_texture:
		_sky_mesh.mesh = QuadMesh.new()
		_sky_mesh.mesh.size = Vector2(30, 30) * bd.sky_scale
		var mat = ShaderMaterial.new()
		mat.shader = LayerScrollShader
		mat.set_shader_parameter("layer_texture", bd.sky_texture)
		mat.set_shader_parameter("scroll_speed", bd.sky_scroll)
		mat.set_shader_parameter("tint", bd.sky_tint)
		_sky_mesh.material_override = mat
		_sky_mesh.position.z = 30.0

	for cfg in bd.layers:
		if not cfg.texture:
			continue
		var mesh_node = MeshInstance3D.new()
		mesh_node.mesh = QuadMesh.new()
		mesh_node.mesh.size = Vector2(20, 20) * cfg.scale
		var mat = ShaderMaterial.new()
		mat.shader = LayerScrollShader
		mat.set_shader_parameter("layer_texture", cfg.texture)
		mat.set_shader_parameter("scroll_speed", cfg.scroll_speed)
		mat.set_shader_parameter("tint", cfg.tint)
		mesh_node.material_override = mat
		mesh_node.position.z = cfg.z_position
		_layer_container.add_child(mesh_node)

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
