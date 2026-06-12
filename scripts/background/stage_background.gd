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
	_process_events()
	_on_update(delta, _elapsed)

func _exit_tree():
	_events.clear()
	_on_cleanup()

func _find_camera() -> Camera3D:
	var parent := get_parent()
	if parent:
		var cam_node := parent.get_node_or_null("Camera3D")
		if cam_node is Camera3D:
			return cam_node
	# 后备：从场景根搜
	var root := get_tree().current_scene
	if root:
		var cam := root.find_child("Camera3D", true, false) as Camera3D
		if cam:
			return cam
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

## 广播滚动倍率给所有子节点
var scroll_mult: float = 1.0

func get_camera_offset() -> Vector3:
	if camera:
		return camera.transform.origin
	return Vector3.ZERO

## 相机旋转 (Euler 角度, 度)
func rotate_camera(target_rot: Vector3, duration: float, ease_type: int = Tween.EASE_IN_OUT, trans_type: int = Tween.TRANS_SINE):
	if not camera:
		return
	var tween = create_tween()
	tween.set_ease(ease_type).set_trans(trans_type)
	tween.tween_property(camera, "rotation", target_rot, duration)

## 推移相机 (相对移动)
func pan_camera(offset: Vector3, duration: float, ease_type: int = Tween.EASE_IN_OUT, trans_type: int = Tween.TRANS_SINE):
	if not camera:
		return
	move_camera(camera.transform.origin + offset, duration, ease_type, trans_type)

func move_camera(target_pos: Vector3, duration: float, ease_type: int = Tween.EASE_IN_OUT, trans_type: int = Tween.TRANS_SINE):
	if not camera:
		return
	var tween = create_tween()
	tween.set_ease(ease_type).set_trans(trans_type)
	tween.tween_property(camera, "transform", Transform3D(camera.transform.basis, target_pos), duration)

## 后处理 — 亮度/对比/饱和
func tween_post_processing(brightness: float = 1.0, contrast: float = 1.0, saturation: float = 1.0, duration: float = 1.0, ease_type: int = Tween.EASE_IN_OUT, trans_type: int = Tween.TRANS_SINE):
	if not world_environment:
		return
	var env := world_environment.environment
	env.adjustment_enabled = true
	var tween = create_tween().set_parallel(true)
	tween.set_ease(ease_type).set_trans(trans_type)
	tween.tween_property(env, "adjustment_brightness", brightness, duration)
	tween.tween_property(env, "adjustment_contrast", contrast, duration)
	tween.tween_property(env, "adjustment_saturation", saturation, duration)

## 真加速推镜 — 持续加速推进 direction 方向, 总时长 duration 秒, 加速度 accel (m/s²)
func camera_rush(direction: Vector3, duration: float, accel: float = 2.0):
	if not camera:
		return
	var vel := Vector3.ZERO
	var elapsed := 0.0
	var origin := camera.transform.origin
	while elapsed < duration and camera:
		var delta := get_process_delta_time()
		vel += direction.normalized() * accel * delta
		var step := vel * delta
		camera.transform.origin += step
		elapsed += delta
		await get_tree().process_frame
	# 可选: 回到原位
	# var tween = create_tween()
	# tween.tween_property(camera, "transform", Transform3D(camera.transform.basis, origin), 0.5)

func _on_setup():
	for child in get_children():
		if child is BackgroundScript:
			child._on_init(StageAPI.new(child))

func _on_update(_delta: float, _t: float):
	pass

func _on_cleanup():
	pass
