extends Node
class_name BgCameraController

var _camera: Camera3D
var _config: BgCameraConfig

var _shake_remaining: float = 0.0
var _shake_intensity: float = 0.0
var _current_tilt_x: float = 0.0
var _current_tilt_y: float = 0.0
var _rng = RandomNumberGenerator.new()

func setup(config: BgCameraConfig, camera: Camera3D):
	_config = config
	_camera = camera
	_rng.randomize()

func trigger_shake(amplitude: float, decay: float):
	_shake_intensity = amplitude
	_shake_remaining = amplitude
	if decay > 0:
		_shake_remaining /= decay

func _process(delta):
	if not _camera or not _config:
		return

	_update_tilt_from_player(delta)
	_apply_shake(delta)
	_push_ground_params()

func _update_tilt_from_player(delta):
	if _config.tilt_response <= 0:
		return

	var player = GameState.player
	if not player:
		_current_tilt_x = move_toward(_current_tilt_x, 0, _config.tilt_smooth * delta)
		_current_tilt_y = move_toward(_current_tilt_y, 0, _config.tilt_smooth * delta)
		return

	var view_center = get_viewport().get_visible_rect().size * 0.5
	var offset = (player.global_position - view_center) / view_center

	var target_x = -offset.x * _config.tilt_response
	var target_y = offset.y * _config.tilt_response

	_current_tilt_x = move_toward(_current_tilt_x, target_x, _config.tilt_smooth * delta)
	_current_tilt_y = move_toward(_current_tilt_y, target_y, _config.tilt_smooth * delta)

func _apply_shake(delta):
	if _shake_intensity <= 0:
		_camera.h_offset = 0
		_camera.v_offset = 0
		return

	var raw_x = _rng.randf_range(-1, 1) * _shake_intensity * 0.05
	var raw_y = _rng.randf_range(-1, 1) * _shake_intensity * 0.05

	_camera.h_offset = lerp(_camera.h_offset, raw_x, 0.3)
	_camera.v_offset = lerp(_camera.v_offset, raw_y, 0.3)

	_shake_intensity = max(_shake_intensity - _config.shake_decay * delta, 0)

func _push_ground_params():
	var parent = get_parent()
	if not parent:
		return
	var ground = parent.get_node_or_null("SubViewport/GroundMesh")
	if not ground or not ground.material_override:
		return

	var mat = ground.material_override
	mat.set_shader_parameter("tilt_x", _current_tilt_x)
	mat.set_shader_parameter("tilt_y", _current_tilt_y)
	mat.set_shader_parameter("fov_stretch", _config.fov_stretch)
	mat.set_shader_parameter("roll", _config.roll)
	mat.set_shader_parameter("camera_speed_mult", 1.0)
