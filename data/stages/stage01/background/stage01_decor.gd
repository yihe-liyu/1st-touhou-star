extends BackgroundScript

@onready var bg: StageBackground = $".."
@onready var ground: BackgroundPlane = $"../Ground"

@export var tree_texture: Texture2D

var _phase = 0
var _loop = 0

func _on_init(api: StageAPI) -> void:
	if bg.world_environment:
		var env := bg.world_environment.environment
		env.fog_light_color = Color.BLACK
		env.fog_density = 0.5
	if bg.camera:
		bg.camera.fov = 55.0

	# 黑雾里预生成树, 雾散时已经在场
	for i in range(200):
		var x = RNG.randf_range(-70, 70)
		var z = RNG.randf_range(-200, -30)
		_spawn(api, tree_texture, Vector2(16, 16), 8.0, x, z)

func _on_step(api: StageAPI) -> Variant:
	_loop += 1
	if _loop == 18:
		var x = RNG.randf_range(-70, 70)
		var z = RNG.randf_range(-220, -180)
		_spawn(api, tree_texture, Vector2(16, 16), 8.0, x, z)
		_loop = 0

	match _phase:
		0:
			_fog_to(Color(0.1, 0.1, 0.1, 0.75), 0.04, 68.0, 12)
			_phase = 1
			return api.seconds(6)
		1:
			bg.pan_camera(Vector3(0, 18, -3), 8.0, Tween.EASE_IN_OUT, Tween.TRANS_QUAD)
			bg.rotate_camera(Vector3(deg_to_rad(-22), 0, deg_to_rad(6)), 6.0, Tween.EASE_IN_OUT, Tween.TRANS_SINE)
			_phase = 2
			return api.seconds(2)
	return true

func _spawn(api: StageAPI, tex: Texture2D, size: Vector2, y: float, x: float, z: float):
	api.spawn_decor_batched(tex, Vector3(x, y, z), size, ground)

func _fog_to(color: Color, density: float, fov: float, sec: float):
	var env := bg.world_environment.environment
	var t := bg.create_tween().set_parallel(true)
	t.tween_property(env, "fog_light_color", color, sec)
	t.tween_property(env, "fog_density", density, sec)
	t.tween_property(bg.camera, "fov", fov, sec)
