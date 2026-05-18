# CameraEffect.gd
extends Node

var ground_mat: ShaderMaterial
var all_sprite_mats: Array = []
var camera_node: Camera3D

var speed_mult: float = 1.0
var shaking: bool = false
var shake_intensity: float = 0.0
var shake_decay: float = 5.0

func _ready():
	camera_node = get_parent().get_node("Camera3D")
	
	# 收集所有材质引用
	var ground = get_parent().get_node_or_null("GroundMesh")
	if ground:
		ground_mat = ground.material_override
	
	for layer_name in ["FarLayer", "MidLayer", "NearLayer"]:
		var layer = get_parent().get_node_or_null(layer_name)
		if layer:
			for child in layer.get_children():
				if child is Sprite3D and child.material_override:
					all_sprite_mats.append(child.material_override)
	
	# 监听全局事件
	GameEvents.graze.connect(func(): start_shake(0.2, 8.0))
	GameEvents.player_damaged.connect(func(_hp): start_shake(0.6, 5.0))
	GameEvents.bomb_used.connect(func(): start_shake(0.8, 3.0))

func _process(delta):
	# 传摄像机位置给所有面片
	var cam_pos = camera_node.global_position
	for mat in all_sprite_mats:
		mat.set_shader_parameter("camera_world_pos", cam_pos)
	
	# 处理震动
	if shaking:
		shake_intensity = max(shake_intensity - shake_decay * delta, 0.0)
		if shake_intensity <= 0.0:
			stop_shake()
		else:
			var r = randf_range(-1.0, 1.0) * shake_intensity
			_set_all("roll", r)
			_set_all("tilt_x", randf_range(-1.0, 1.0) * shake_intensity * 0.6)
			_set_all("tilt_y", randf_range(-1.0, 1.0) * shake_intensity * 0.6)

func set_speed_mult(m: float):
	speed_mult = m
	_set_all("camera_speed_mult", m)

func start_shake(intensity: float, decay: float):
	shake_intensity = intensity
	shake_decay = decay
	shaking = true

func stop_shake():
	shaking = false
	_set_all("roll", 0.0)
	_set_all("tilt_x", 0.0)
	_set_all("tilt_y", 0.0)

func _set_all(param: String, value):
	if ground_mat:
		ground_mat.set_shader_parameter(param, value)
	for mat in all_sprite_mats:
		mat.set_shader_parameter(param, value)
