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


## 伪日食太阳（Sprite3D）：背景正常、太阳专门被遮——黑圆+漏光纹理（绝对正圆）
## billboard 用 SpriteBase3D 原生属性（此 fork 未阉割）；雾豁免用极简 shader
func _spawn_sun() -> void:
	if bg.get_node_or_null("EclipseSun"):
		return
	var sun := Sprite3D.new()
	sun.name = "EclipseSun"
	sun.texture = _make_sun_texture(256)
	sun.pixel_size = 0.31  # 256px → 世界直径约 80
	sun.billboard = BaseMaterial3D.BILLBOARD_ENABLED  # SpriteBase3D 原生属性
	sun.position = Vector3(0, 100, -320)
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://gdshader/sun_sprite.gdshader")
	mat.set_shader_parameter("sun_tex", sun.texture)
	sun.material_override = mat
	bg.add_child(sun)


## 逐像素生成太阳纹理：暗暖本体（被遮的太阳）+ 边缘漏光 + 日冕光晕
func _make_sun_texture(size: int) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var r: float = 0.30      # 黑圆半径（归一化）
	var edge: float = 0.015  # 边缘过渡
	for y in range(size):
		for x in range(size):
			var p := Vector2((x + 0.5) / size, (y + 0.5) / size) - Vector2(0.5, 0.5)
			var d: float = p.length() * 2.0
			var body: float = 1.0 - smoothstep(r - edge, r + edge, d)
			var ring: float = exp(-max(d - r, 0.0) * 12.0) * 0.95
			# 光晕只延伸到圆外 0.42（d<0.72）——超出区域 alpha 归零，避免方形纹理边缘可见
			var halo: float = exp(-max(d - r, 0.0) * 2.5) * 0.38 * (1.0 - smoothstep(0.55, 0.72, d))
			var c := Color(1.0, 0.92, 0.72) * (ring + halo)
			if body > 0.0:
				c = c.lerp(Color(0.07, 0.05, 0.035), body)
			var a: float = clampf(max(body, ring + halo), 0.0, 1.0)
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
