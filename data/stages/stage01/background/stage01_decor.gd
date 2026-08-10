extends CoroutineScript
## Stage01 背景演出 —— 时间线版（组件化：环境/太阳/蒙眼雾已抽成组件与基类 API）
## 环境预设 stage01_env.tres 管"初始状态"，tween_env_* 管"动态变化"，本脚本只做编排

@onready var bg: StageBackground = $".."
@onready var ground: BackgroundPlane = $"../Ground"
@onready var sun: BackgroundSun = $"../Sun"
@onready var fog: ScreenFogFX = $"../FogFX"

const OAK_LAYER = preload("res://data/stages/stage01/background/oak.tres")
const ENV_PRESET = preload("res://data/stages/stage01/background/stage01_env.tres")


func _ready() -> void:
	# practice 模式不调 start（无演出），但也要有环境 → 这里应用预设
	bg.apply_env_preset(ENV_PRESET)


func start(p_ctx: StageContext, p_target: Node2D = null):
	ctx = p_ctx
	if p_target:
		target = p_target
	
	# 重跑重置：全新环境 + 相机复位（防 tween 残留/越重跑越暗）
	bg.apply_env_preset(ENV_PRESET)
	bg.reset_camera()
	sun.setup()
	fog.setup(sun)
	ctx.decor.add_layer(OAK_LAYER)
	ctx.decor.batch_spawn("橡树", 160, Vector2(-90, 90), Vector2(-220, -50), ground)
	
	var tl := start_timeline()

	# ① 雾散光来 (0→6s, tween 12s)
	tl.at(0.0).do(func():
		bg.tween_env_fog(Color(0.7, 0.6, 0.6, 0.75), 0.02, 12.0)  # 密度 0.014：近处草纹清晰，远处融进雾色
		bg.tween_env_fov(68.0, 12.0)
	)

	# ② 相机移动 + 旋转 (6s)
	tl.at(6.0).do(func():
		bg.pan_camera(Vector3(0, 20, -3), 8.0, Tween.EASE_IN_OUT, Tween.TRANS_QUAD)
		bg.rotate_camera(Vector3(deg_to_rad(-30), 0, 0), 6.0, Tween.EASE_IN_OUT, Tween.TRANS_SINE)
	)

	# ③ 地面加速 (10s)
	tl.at(10.0).do(func():
		var t := bg.create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
		t.tween_method(_camera_accel, 1.0, 7.0, 32).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	)

	# ④ 每 4 帧喷一棵树（持续）
	tl.at(0.0).every(4.0 / Engine.physics_ticks_per_second).do(func():
		var x: float = RNG.randf_range(-190, 190)
		var z: float = RNG.randf_range(-420, -180)
		ctx.decor.spawn("橡树", Vector3(x, 8.0, z), Vector2.ZERO, ground)
	)

	super.start(ctx, target)


func _camera_accel(mult: float):
	ground.scroll_speed = Vector2(0, -0.1 * mult)
