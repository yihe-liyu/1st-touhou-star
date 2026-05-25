extends Node3D
class_name StageBackground

var camera: Camera3D
var _elapsed: float = 0.0
var _events: Dictionary = {}
var _active: bool = false
var _tweening: bool = false

func _ready():
	camera = _find_camera()
	_on_setup()

func _process(delta):
	if not _active:
		_active = true
	_elapsed += delta
	_process_events()
	_on_update(delta, _elapsed)

func _exit_tree():
	_events.clear()
	_on_cleanup()

func _find_camera() -> Camera3D:
	var parent = get_parent()
	if parent:
		var cam_node = parent.get_node_or_null("Camera3D")
		if cam_node is Camera3D:
			return cam_node
	return null

func schedule(time_sec: float, callback: Callable):
	if not _events.has(time_sec):
		_events[time_sec] = []
	_events[time_sec].append(callback)

func _process_events():
	var expired: Array = []
	for time in _events:
		if _elapsed >= time:
			for cb in _events[time]:
				cb.call()
			expired.append(time)
	for time in expired:
		_events.erase(time)

func set_camera_fov(fov: float):
	if camera:
		camera.fov = fov

func set_camera_size(size: float):
	if camera:
		camera.size = size

func set_camera_z(z: float):
	if camera:
		var t = camera.transform
		t.origin.z = z
		camera.transform = t

func set_camera_y(y: float):
	if camera:
		var t = camera.transform
		t.origin.y = y
		camera.transform = t

func set_camera_x(x: float):
	if camera:
		var t = camera.transform
		t.origin.x = x
		camera.transform = t

func set_camera_pos(pos: Vector3):
	if camera:
		var t = camera.transform
		t.origin = pos
		camera.transform = t

func get_camera_offset() -> Vector3:
	if camera:
		return camera.transform.origin
	return Vector3.ZERO

func move_camera(target_pos: Vector3, duration: float):
	if not camera:
		return
	var tween = create_tween()
	tween.tween_property(camera, "transform", Transform3D(camera.transform.basis, target_pos), duration)

func _on_setup():
	pass

func _on_update(_delta: float, _elapsed: float):
	pass

func _on_cleanup():
	pass
