extends BackgroundScript

@onready var bg: StageBackground = $".."
@onready var ground: BackgroundPlane = $"../Ground"

const OAK_LAYER = preload("res://data/decor_layers/oak.tres")

var _phase: int = 0
var _loop: int = 0

func _on_init(api: StageAPI) -> void:
	if bg.world_environment:
		var env := bg.world_environment.environment
		env.fog_light_color = Color.BLACK
		env.fog_density = 0.5
	if bg.camera:
		bg.camera.fov = 55.0

	# 注册分层
	api.add_decor_layer(OAK_LAYER)

	# 黑雾里预生成树, 雾散时已经在场
	api.batch_spawn_decor("橡树", 160, Vector2(-90, 90), Vector2(-220, -50), ground)

func _on_step(api: StageAPI) -> Variant:
	_loop += 1
	if _loop == 4:
		var x: float = RNG.randf_range(-90, 90)
		var z: float = RNG.randf_range(-220, -180)
		api.spawn_decor("橡树", Vector3(x, 8.0, z), Vector2.ZERO, ground)
		_loop = 0

	match _phase:
		0:
			_fog_to(Color(0.1, 0.1, 0.1, 0.75), 0.04, 68.0, 12)
			_phase = 1
			return api.seconds(6)
		1:
			bg.pan_camera(Vector3(0, 20, -3), 8.0, Tween.EASE_IN_OUT, Tween.TRANS_QUAD)
			bg.rotate_camera(Vector3(deg_to_rad(-22), 0, deg_to_rad(6)), 6.0, Tween.EASE_IN_OUT, Tween.TRANS_SINE)
			_phase = 2
			return api.seconds(4)
		2:
			var t_accel := bg.create_tween()
			t_accel.tween_method(_camera_accel, 1.0, 7.0, 16).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
			_phase = 3
			return api.seconds(1)
	return true

func _fog_to(color: Color, density: float, fov: float, sec: float):
	var env := bg.world_environment.environment
	var t := bg.create_tween().set_parallel(true)
	t.tween_property(env, "fog_light_color", color, sec)
	t.tween_property(env, "fog_density", density, sec)
	t.tween_property(bg.camera, "fov", fov, sec)

func _camera_accel(mult: float):
	ground.scroll_speed = Vector2(0, -0.1 * mult)
