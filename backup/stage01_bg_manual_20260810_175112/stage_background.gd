# ═══ 以下为备份原始内容，已整体注释（防止 Godot 扫描 class_name 冲突）═══
# extends Node3D
# class_name StageBackground
# 
# ## 公开：背景脚本可直接读写
# var camera: Camera3D
# var world_environment: WorldEnvironment
# var _elapsed: float = 0.0
# var _events: Dictionary = {}
# var _active: bool = false
# 
# func _ready():
# 	camera = _find_camera()
# 	world_environment = _find_world_environment()
# 	# 关键：Environment 是场景 SubResource，多个实例共享同一资源！
# 	# 重跑/多背景实例会互相污染（雾/环境光状态残留）→ duplicate 成实例私有
# 	# （否则每次实例化拿到的是上一次 tween 改过的状态 → "越重跑越暗"）
# 	if world_environment and world_environment.environment:
# 		world_environment.environment = world_environment.environment.duplicate()
# 	# 无外部相机（工作台等复用场景）→ 自建随本实例销毁的相机
# 	# 这样重跑时旧相机随背景销毁、新背景拿初始相机，零残留、无需手动复位
# 	if camera == null:
# 		_own_camera()
# 	_on_setup()
# 
# 
# ## 自建相机：初始姿态与真游戏 SubViewport 相机一致；随本背景实例销毁
# func _own_camera() -> void:
# 	var cam := Camera3D.new()
# 	cam.name = "Camera3D"
# 	cam.position = Vector3(0, 10, 6)
# 	cam.rotation_degrees = Vector3(-30, 0, 0)
# 	cam.fov = 55.0
# 	add_child(cam)
# 	camera = cam
# 
# func _process(delta):
# 	if not _active:
# 		_active = true
# 	_elapsed += delta
# 	_process_events()
# 	_on_update(delta, _elapsed)
# 
# func _exit_tree():
# 	_events.clear()
# 	_on_cleanup()
# 
# func _find_camera() -> Camera3D:
# 	var parent := get_parent()
# 	if parent:
# 		var cam_node := parent.get_node_or_null("Camera3D")
# 		if cam_node is Camera3D:
# 			return cam_node
# 	# 后备：从场景根搜
# 	var root := get_tree().current_scene
# 	if root:
# 		var cam := root.find_child("Camera3D", true, false) as Camera3D
# 		if cam:
# 			return cam
# 	return null
# 
# func _find_world_environment() -> WorldEnvironment:
# 	for child in get_children():
# 		if child is WorldEnvironment:
# 			return child
# 	return null
# 
# func schedule(time_sec: float, callback: Callable):
# 	if not _events.has(time_sec):
# 		_events[time_sec] = []
# 	_events[time_sec].append(callback)
# 
# func _process_events():
# 	var expired: Array = []
# 	for time in _events:
# 		if _elapsed >= time:
# 			for cb in _events[time]:
# 				cb.call()
# 			expired.append(time)
# 	for time in expired:
# 		_events.erase(time)
# 
# func set_camera_fov(fov: float):
# 	if camera:
# 		camera.fov = fov
# 
# func set_camera_size(size: float):
# 	if camera:
# 		camera.size = size
# 
# func set_camera_z(z: float):
# 	if camera:
# 		var t = camera.transform
# 		t.origin.z = z
# 		camera.transform = t
# 
# func set_camera_y(y: float):
# 	if camera:
# 		var t = camera.transform
# 		t.origin.y = y
# 		camera.transform = t
# 
# func set_camera_x(x: float):
# 	if camera:
# 		var t = camera.transform
# 		t.origin.x = x
# 		camera.transform = t
# 
# func set_camera_pos(pos: Vector3):
# 	if camera:
# 		var t = camera.transform
# 		t.origin = pos
# 		camera.transform = t
# 
# ## 广播滚动倍率给所有子节点
# var scroll_mult: float = 1.0
# 
# func get_camera_offset() -> Vector3:
# 	if camera:
# 		return camera.transform.origin
# 	return Vector3.ZERO
# 
# ## 相机旋转 (Euler 角度, 度)
# func rotate_camera(target_rot: Vector3, duration: float, ease_type: int = Tween.EASE_IN_OUT, trans_type: int = Tween.TRANS_SINE):
# 	if not camera:
# 		return
# 	var tween: Tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
# 	tween.set_ease(ease_type).set_trans(trans_type)
# 	tween.tween_property(camera, "rotation", target_rot, duration)
# 
# ## 推移相机 (相对移动)
# func pan_camera(offset: Vector3, duration: float, ease_type: int = Tween.EASE_IN_OUT, trans_type: int = Tween.TRANS_SINE):
# 	if not camera:
# 		return
# 	move_camera(camera.transform.origin + offset, duration, ease_type, trans_type)
# 
# func move_camera(target_pos: Vector3, duration: float, ease_type: int = Tween.EASE_IN_OUT, trans_type: int = Tween.TRANS_SINE):
# 	if not camera:
# 		return
# 	var tween: Tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
# 	tween.set_ease(ease_type).set_trans(trans_type)
# 	tween.tween_property(camera, "position", target_pos, duration)
# 
# ## 真加速推镜 — 持续加速推进 direction 方向, 总时长 duration 秒, 加速度 accel (m/s²)
# func camera_rush(direction: Vector3, duration: float, accel: float = 2.0):
# 	if not camera:
# 		return
# 	var vel := Vector3.ZERO
# 	var elapsed := 0.0
# 	var origin := camera.transform.origin
# 	while elapsed < duration and camera:
# 		var delta := get_process_delta_time()
# 		vel += direction.normalized() * accel * delta
# 		var step := vel * delta
# 		camera.transform.origin += step
# 		elapsed += delta
# 		await get_tree().process_frame
# 	# 可选: 回到原位
# 	# var tween = create_tween()
# 	# tween.tween_property(camera, "transform", Transform3D(camera.transform.basis, origin), 0.5)
# 
# func _on_setup():
# 	# 子 CoroutineScript 由 StageManager 统一 start()
# 	pass
# 
# func _on_update(_delta: float, _t: float):
# 	pass
# 
# func _on_cleanup():
# 	pass
# 
# # ═══ 光照 ═══
# 
# var sun_light: DirectionalLight3D
# 
# func setup_sun() -> void:
# 	sun_light = DirectionalLight3D.new()
# 	sun_light.name = "Sun"
# 	sun_light.light_energy = 0.0
# 	sun_light.light_color = Color.BLACK
# 	sun_light.shadow_enabled = false
# 	add_child(sun_light)
# 
# func set_sun_color(color: Color, duration: float = 2.0) -> void:
# 	if not sun_light: return
# 	var tw := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
# 	tw.tween_property(sun_light, "light_color", color, duration)
# 
# func set_sun_energy(energy: float, duration: float = 2.0) -> void:
# 	if not sun_light: return
# 	var tw := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
# 	tw.tween_property(sun_light, "light_energy", energy, duration)
# 
# func set_sun_rotation(rot: Vector3, duration: float = 2.0) -> void:
# 	if not sun_light: return
# 	var tw := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
# 	tw.tween_property(sun_light, "rotation", rot, duration)
