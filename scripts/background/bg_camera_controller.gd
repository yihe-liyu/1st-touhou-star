extends Node
class_name BgCameraController

@export var shake_decay: float = 4.0

var fov_stretch: float = 0.0
var roll: float = 0.0
var camera_speed_mult: float = 1.0

var _camera: Camera3D
var _shake_intensity: float = 0.0
var _shake_current_decay: float = 4.0
var _rng = RandomNumberGenerator.new()
var _initial_position: Vector3
var _initial_rotation_degrees: Vector3
var _initial_fov: float = 75.0

func setup(camera: Camera3D):
	_camera = camera
	_initial_position = camera.position
	_initial_rotation_degrees = camera.rotation_degrees
	_initial_fov = camera.fov
	_rng.randomize()

func trigger_shake(amplitude: float, decay: float = -1.0):
	_shake_intensity = amplitude
	_shake_current_decay = decay if decay > 0 else shake_decay

func set_camera_position(pos: Vector3):
	if _camera:
		_camera.position = pos

func get_camera_position() -> Vector3:
	return _camera.position if _camera else Vector3.ZERO

func set_camera_rotation_degrees(rot: Vector3):
	if _camera:
		_camera.rotation_degrees = rot

func get_camera_rotation_degrees() -> Vector3:
	return _camera.rotation_degrees if _camera else Vector3.ZERO

func set_camera_fov(fov: float):
	if _camera:
		_camera.fov = fov

func get_camera_fov() -> float:
	return _camera.fov if _camera else 75.0

func set_fov_stretch(value: float):
	fov_stretch = value

func get_fov_stretch() -> float:
	return fov_stretch

func set_roll(value: float):
	roll = value

func get_roll() -> float:
	return roll

func set_camera_speed_mult(value: float):
	camera_speed_mult = value

func get_camera_speed_mult() -> float:
	return camera_speed_mult

func reset_camera():
	if not _camera:
		return
	_camera.position = _initial_position
	_camera.rotation_degrees = _initial_rotation_degrees
	_camera.fov = _initial_fov
	_camera.h_offset = 0
	_camera.v_offset = 0

func _process(delta):
	if not _camera:
		return
	_apply_shake(delta)
	_push_ground_params()

func _apply_shake(delta):
	if _shake_intensity <= 0:
		_camera.h_offset = 0
		_camera.v_offset = 0
		return
	var raw_x = _rng.randf_range(-1, 1) * _shake_intensity * 0.05
	var raw_y = _rng.randf_range(-1, 1) * _shake_intensity * 0.05
	_camera.h_offset = lerp(_camera.h_offset, raw_x, 0.3)
	_camera.v_offset = lerp(_camera.v_offset, raw_y, 0.3)
	_shake_intensity = max(_shake_intensity - _shake_current_decay * delta, 0)

func _push_ground_params():
	var parent = get_parent()
	if not parent:
		return
	var ground = parent.get_node_or_null("SubViewport/GroundMesh")
	if not ground or not ground.material_override:
		return
	var mat = ground.material_override
	mat.set_shader_parameter("fov_stretch", fov_stretch)
	mat.set_shader_parameter("roll", roll)
	mat.set_shader_parameter("camera_speed_mult", camera_speed_mult)
