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
	env.fog_density = 0.15  # 背景正常（日食感集中在太阳，不全局浓雾）
	# 程序化天空：微暗蒙眼的白天（伪日食下"黑蒙蒙的天"，但看得出是白天）
	var sky := ProceduralSkyMaterial.new()
	sky.sky_top_color = Color(0.20, 0.24, 0.30)       # 天顶：暗蓝灰
	sky.sky_horizon_color = Color(0.42, 0.44, 0.46)   # 地平线：稍亮
	sky.sky_curve = 0.35
	sky.ground_horizon_color = Color(0.30, 0.33, 0.30)
	sky.ground_bottom_color = Color(0.16, 0.18, 0.14)
	env.background_mode = Environment.BG_SKY
	env.sky = Sky.new()
	env.sky.sky_material = sky
	env.fog_sky_affect = 0.0  # 雾不染黑天空（否则无限远天空被雾全黑）
	# glow 泛光：太阳 EMISSION HDR 辉光（之前默认关 → 太阳"光"感差）
	env.glow_enabled = true
	env.glow_intensity = 0.8
	env.glow_bloom = 0.1
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	if bg.camera:
		bg.camera.fov = 55.0


func start(p_ctx: StageContext, p_target: Node2D = null):
	ctx = p_ctx
	if p_target:
		target = p_target
	
	_reset_environment()
	_spawn_sun()
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


## 伪日食太阳（两层分开）：① 规则亮圆太阳 + ② 不规则黑雾（shader 噪声边缘 + 时间驱动飘动）
func _spawn_sun() -> void:
	if bg.get_node_or_null("EclipseSun"):
		return
	# 层①：规则圆太阳（Image 画的正圆，干净发光）
	var sun := Sprite3D.new()
	sun.name = "EclipseSun"
	sun.texture = _make_sun_disc(256)
	sun.pixel_size = 0.31
	sun.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sun.position = Vector3(0, 100, -320)
	var smat := ShaderMaterial.new()
	smat.shader = preload("res://gdshader/sun_sprite.gdshader")
	smat.set_shader_parameter("sun_tex", sun.texture)
	sun.material_override = smat
	bg.add_child(sun)
	# 层②：不规则黑雾（盖住太阳中心，边缘漏出规则的圆太阳边）
	var shade := Sprite3D.new()
	shade.name = "EclipseShade"
	shade.texture = sun.texture  # 占位（黑雾 shader 不采样纹理）
	shade.pixel_size = 0.31
	shade.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	shade.position = sun.position
	var hmat := ShaderMaterial.new()
	hmat.shader = preload("res://gdshader/eclipse_shade.gdshader")
	shade.material_override = hmat
	bg.add_child(shade)


## 规则圆太阳纹理：中心亮暖白、边缘柔和、外圈光晕——干净的正圆（黑雾层负责遮）
func _make_sun_disc(size: int) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in range(size):
		for x in range(size):
			var p := Vector2((x + 0.5) / size, (y + 0.5) / size) - Vector2(0.5, 0.5)
			var d: float = p.length() * 2.0
			var disc: float = 1.0 - smoothstep(0.40, 0.48, d)      # 规则圆盘
			var glow: float = exp(-max(d - 0.46, 0.0) * 6.0) * 0.5  # 外圈光晕
			var c := Color(1.0, 0.96, 0.84) * (0.45 + 0.55 * disc) + Color(1.0, 0.85, 0.55) * glow
			var a: float = clampf(disc + glow, 0.0, 1.0)
			img.set_pixel(x, y, Color(c.r, c.g, c.b, a))
	return ImageTexture.create_from_image(img)

func _fog_to(color: Color, density: float, fov: float, sec: float):
	var env := bg.world_environment.environment
	var t := bg.create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS).set_parallel(true)
	t.tween_property(env, "fog_light_color", color, sec)
	t.tween_property(env, "fog_density", density, sec)
	t.tween_property(bg.camera, "fov", fov, sec)

func _camera_accel(mult: float):
	ground.scroll_speed = Vector2(0, -0.1 * mult)
