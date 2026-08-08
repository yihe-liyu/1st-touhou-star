extends CoroutineScript
## Stage01 背景演出 —— 时间线版

@onready var bg: StageBackground = $".."
@onready var ground: BackgroundPlane = $"../Ground"

const OAK_LAYER = preload("res://data/stages/stage01/background/oak.tres")


func _ready() -> void:
	_reset_environment()


func _reset_environment() -> void:
	if not bg.world_environment: return
	var env := bg.world_environment.environment
	env.fog_light_color = Color.BLACK
	env.fog_density = 0.5
	if bg.camera:
		bg.camera.fov = 55.0


func start(p_ctx: StageContext, p_target: Node2D = null):
	ctx = p_ctx
	if p_target:
		target = p_target
	
	_reset_environment()
	_setup_eclipse_sky()
	ctx.decor.add_layer(OAK_LAYER)
	ctx.decor.batch_spawn("橡树", 160, Vector2(-90, 90), Vector2(-220, -50), ground)
	
	var tl := start_timeline()

	# ① 雾散光来 (0→6s, tween 12s)
	tl.at(0.0).do(func():
		_fog_to(Color(0.0, 0.0, 0.0, 0.5), 0.04, 68.0, 12)
	)

	# ② 相机移动 + 旋转 (6s)
	tl.at(6.0).do(func():
		bg.pan_camera(Vector3(0, 20, -3), 8.0, Tween.EASE_IN_OUT, Tween.TRANS_QUAD)
		bg.rotate_camera(Vector3(deg_to_rad(-22), 0, deg_to_rad(6)), 6.0, Tween.EASE_IN_OUT, Tween.TRANS_SINE)
	)

	# ③ 地面加速 (10s)
	tl.at(10.0).do(func():
		var t := bg.create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
		t.tween_method(_camera_accel, 1.0, 7.0, 32).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	)

	# ④ 每 4 帧喷一棵树（持续）
	tl.at(0.0).every(4.0 / Engine.physics_ticks_per_second).do(func():
		var x: float = RNG.randf_range(-90, 90)
		var z: float = RNG.randf_range(-220, -180)
		ctx.decor.spawn("橡树", Vector3(x, 8.0, z), Vector2.ZERO, ground)
	)

	super.start(ctx, target)


## 伪日食天空（Godot 原生 Sky：ProceduralSkyMaterial 天色 + DirectionalLight3D 太阳光斑）
## fog_sky_affect=0 → 雾不盖天空，太阳穿过雾清晰可见（不用 fog_disabled hack）
func _setup_eclipse_sky() -> void:
	var env := bg.world_environment.environment
	if not env:
		return
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.09, 0.10, 0.13)      # 暗蓝灰（压抑）
	sky_mat.sky_horizon_color = Color(0.22, 0.23, 0.28)  # 地平线稍亮
	sky_mat.sky_curve = 0.06
	sky_mat.ground_bottom_color = Color(0.02, 0.02, 0.04)
	sky_mat.ground_horizon_color = Color(0.15, 0.15, 0.19)
	sky_mat.energy_multiplier = 0.55
	sky_mat.sun_angle_max = 18.0                          # 太阳光斑角尺寸
	sky_mat.sun_curve = 0.2
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.fog_sky_affect = 0.0
	# 太阳方向/亮度（ProceduralSky 光斑由 DirectionalLight3D 驱动；场景地面/树都是 unshaded，不受光照）
	bg.setup_sun()
	# 光从前方斜射（默认朝 -Z；光斑显示在光的来向 = 相机左前上方地平线附近）
	bg.set_sun_rotation(Vector3(deg_to_rad(6.0), deg_to_rad(-18.0), 0.0))
	bg.set_sun_energy(1.6)
	if bg.sun_light:
		bg.sun_light.light_color = Color(0.90, 0.93, 1.0)


func _fog_to(color: Color, density: float, fov: float, sec: float):
	var env := bg.world_environment.environment
	var t := bg.create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS).set_parallel(true)
	t.tween_property(env, "fog_light_color", color, sec)
	t.tween_property(env, "fog_density", density, sec)
	t.tween_property(bg.camera, "fov", fov, sec)

func _camera_accel(mult: float):
	ground.scroll_speed = Vector2(0, -0.1 * mult)
