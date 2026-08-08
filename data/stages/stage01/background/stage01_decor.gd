extends CoroutineScript
## Stage01 背景演出 —— 时间线版

@onready var bg: StageBackground = $".."
@onready var ground: BackgroundPlane = $"../Ground"

const OAK_LAYER = preload("res://data/stages/stage01/background/oak.tres")

var _sun_3d: MeshInstance3D = null    # 3D 太阳球（挂相机）
var _fog_layer: CanvasLayer = null   # 2D 雾层（屏幕空间）
var _fog_rect: ColorRect = null      # 雾片（对准太阳投影）

func _exit_tree() -> void:
	if _sun_3d and is_instance_valid(_sun_3d):
		_sun_3d.queue_free()
		_sun_3d = null
	if _fog_layer and is_instance_valid(_fog_layer):
		_fog_layer.queue_free()
		_fog_layer = null
	_fog_rect = null


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

	# 雾淡入（6s 相机抬起、天空可见时）
	tl.at(6.0).do(func():
		var t := bg.create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
		t.tween_property(_fog_rect, "modulate:a", 1.0, 2.0)
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


## 伪日食天空：sky shader（官方文档入口 void sky() + out vec3 COLOR + EYEDIR + LIGHT0_*）
## 关键：DirectionalLight3D.sky_mode 默认 LIGHT_ONLY 不驱动天空——用 SKY_ONLY（只驱动天空不照场景）
## fog_sky_affect=0 → 雾不盖天空；相机 6s 抬起后可见
func _setup_eclipse_sky() -> void:
	var env := bg.world_environment.environment
	if not env:
		return
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = preload("res://gdshader/eclipse_sky.gdshader")
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.fog_sky_affect = 0.0

	# 3D 太阳球（挂相机局部——规矩圆；fog_disabled 不被雾吃）
	_sun_3d = MeshInstance3D.new()
	_sun_3d.name = "EclipseSun3D"
	var sphere := SphereMesh.new()
	sphere.radius = 7.0
	sphere.height = 14.0
	var smat := ShaderMaterial.new()
	smat.shader = preload("res://gdshader/sun_sphere.gdshader")
	sphere.material = smat
	_sun_3d.mesh = sphere
	_sun_3d.position = Vector3(0, 18, -90)   # 相机局部：地平线上方天空（6s 相机抬起后可见，屏幕上部 34%）
	bg.camera.add_child(_sun_3d)

	# 2D 黑雾（屏幕空间 CanvasLayer——覆在太阳球投影上；6s 相机抬起后淡入）
	# 太阳球投影（fov 68 相机抬起后）= 屏幕 (384, 294)
	_fog_layer = CanvasLayer.new()
	_fog_layer.layer = 5
	_fog_layer.name = "EclipseFogLayer"
	bg.get_viewport().add_child(_fog_layer)
	_fog_rect = ColorRect.new()
	_fog_rect.size = Vector2(300, 300)
	_fog_rect.position = Vector2(384 - 150, 294 - 150)
	_fog_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fmat := ShaderMaterial.new()
	fmat.shader = preload("res://gdshader/eclipse_fog.gdshader")
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 5
	noise.frequency = 0.006
	var ntex := NoiseTexture2D.new()
	ntex.noise = noise
	ntex.width = 256
	ntex.height = 256
	ntex.seamless = true
	fmat.set_shader_parameter("cloud", ntex)
	_fog_rect.material = fmat
	_fog_rect.modulate.a = 0.0   # 6s 相机抬起后淡入
	_fog_layer.add_child(_fog_rect)


func _fog_to(color: Color, density: float, fov: float, sec: float):
	var env := bg.world_environment.environment
	var t := bg.create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS).set_parallel(true)
	t.tween_property(env, "fog_light_color", color, sec)
	t.tween_property(env, "fog_density", density, sec)
	t.tween_property(bg.camera, "fov", fov, sec)

func _camera_accel(mult: float):
	ground.scroll_speed = Vector2(0, -0.1 * mult)
