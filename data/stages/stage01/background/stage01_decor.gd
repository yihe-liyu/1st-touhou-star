extends CoroutineScript
## Stage01 背景演出 —— 时间线版

@onready var bg: StageBackground = $".."
@onready var ground: BackgroundPlane = $"../Ground"

const OAK_LAYER = preload("res://data/stages/stage01/background/oak.tres")



func _ready() -> void:
	_reset_environment()
	# Boss 击破 → 回光（雾散 + 漏光增强）——片律之妖的日食幻觉消退
	GameEvents.phase_end.connect(_on_phase_end)




func _on_phase_end(_captured: bool, _bonus: int) -> void:
	_fog_to_density(0.03, 5.0)


func _reset_environment() -> void:
	if not bg.world_environment: return
	var env := bg.world_environment.environment
	env.fog_light_color = Color.BLACK
	env.fog_density = 0.06
	if bg.camera:
		bg.camera.fov = 55.0


func start(p_ctx: StageContext, p_target: Node2D = null):
	ctx = p_ctx
	if p_target:
		target = p_target
	
	_reset_environment()
	ctx.decor.add_layer(OAK_LAYER)
	ctx.decor.batch_spawn("橡树", 160, Vector2(-90, 90), Vector2(-220, -50), ground)

	var tl := start_timeline()

	# ① 拉远视角 (0→12s, fov 55→68；雾保持压抑——伪日食不散)
	tl.at(0.0).do(func():
		_fov_to(68.0, 12)
	)

	# ② 相机移动 + 旋转 (6s)
	tl.at(6.0).do(func():
		bg.pan_camera(Vector3(0, 20, -3), 8.0, Tween.EASE_IN_OUT, Tween.TRANS_QUAD)
		bg.rotate_camera(Vector3(deg_to_rad(-22), 0, deg_to_rad(6)), 6.0, Tween.EASE_IN_OUT, Tween.TRANS_SINE)
	)

	# ②b 雾密度联动（伪日食节奏，对齐弹幕）：
	#    开场 0.5 → logo 微亮 0.35（"周边露出较亮的太阳光芒"）→ 中线回压 0.45
	#    → 双路 0.5 → Boss 入场 0.6（片律之妖现身，最压抑）
	tl.at(7.0).do(func():
		_fog_to_density(0.035, 6.0)
	)
	tl.at(11.0).do(func():
		_fog_to_density(0.05, 4.0)
	)
	tl.at(17.0).do(func():
		_fog_to_density(0.06, 4.0)
	)
	tl.at(35.0).do(func():
		_fog_to_density(0.09, 4.0)
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


func _fog_to_density(density: float, sec: float):
	var env := bg.world_environment.environment
	var t := bg.create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	t.tween_property(env, "fog_density", density, sec)


func _fov_to(fov: float, sec: float):
	var t := bg.create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	t.tween_property(bg.camera, "fov", fov, sec)

func _camera_accel(mult: float):
	ground.scroll_speed = Vector2(0, -0.1 * mult)
