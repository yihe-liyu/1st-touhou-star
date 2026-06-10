extends Node3D
class_name StageBackground

## 公开：背景脚本可直接读写
var camera: Camera3D
var world_environment: WorldEnvironment
var _elapsed: float = 0.0
var _events: Dictionary = {}
var _active: bool = false

func _ready():
	camera = _find_camera()
	world_environment = _find_world_environment()
	_on_setup()

func _process(delta):
	if not _active:
		_active = true
	_elapsed += delta
	_update_scroll(delta)
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

func _find_world_environment() -> WorldEnvironment:
	for child in get_children():
		if child is WorldEnvironment:
			return child
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

func _update_scroll(delta: float):
	for child in get_children():
		if child is MeshInstance3D:
			var speed: Vector2 = child.get_meta("scroll_speed", Vector2.ZERO)
			if speed == Vector2.ZERO:
				continue
			var mat: StandardMaterial3D = child.material_override as StandardMaterial3D
			if not mat:
				mat = StandardMaterial3D.new()
				mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				var mesh_inst: MeshInstance3D = child as MeshInstance3D
				if mesh_inst.mesh and mesh_inst.mesh.material:
					var src_mat = mesh_inst.mesh.material
					if src_mat is BaseMaterial3D:
						mat.albedo_texture = src_mat.albedo_texture
				child.material_override = mat
			mat.uv1_offset += Vector3(speed.x * delta, speed.y * delta, 0.0)

func _on_setup():
	pass

func _on_update(_delta: float, _t: float):
	pass

func _on_cleanup():
	pass
