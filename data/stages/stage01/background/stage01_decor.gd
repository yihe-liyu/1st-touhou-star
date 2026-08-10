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


## 伪日食太阳（2D）：CanvasLayer + 程序生成纹理——天然正圆、不受雾影响、固定屏幕位置（天文视差≈0）
func _spawn_sun() -> void:
	if bg.get_node_or_null("SunLayer"):
		return
	var layer := CanvasLayer.new()
	layer.name = "SunLayer"
	layer.layer = 5  # 叠在 3D 背景之上
	bg.add_child(layer)
	var tr := TextureRect.new()
	tr.texture = _make_sun_texture(256)
	tr.size = Vector2(280, 280)
	var vp_size: Vector2 = bg.get_viewport().get_visible_rect().size
	tr.position = Vector2(vp_size.x * 0.5 - 140.0, vp_size.y * 0.10)
	layer.add_child(tr)


## 逐像素生成太阳纹理：暗暖本体（被遮的太阳）+ 边缘漏光 + 日冕光晕
func _make_sun_texture(size: int) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var r: float = 0.30      # 黑圆半径（归一化）
	var edge: float = 0.015  # 边缘过渡
	for y in range(size):
		for x in range(size):
			var p := Vector2((x + 0.5) / size, (y + 0.5) / size) - Vector2(0.5, 0.5)
			var d: float = p.length() * 2.0
			# 黑圆本体（暗暖太阳表面，被黑圆遮住但仍"发着被压暗的光"）
			var body: float = 1.0 - smoothstep(r - edge, r + edge, d)
			# 边缘漏光 + 日冕光晕（指数衰减，画进纹理无需 HDR glow）
			var ring: float = exp(-max(d - r, 0.0) * 12.0) * 0.95
			var halo: float = exp(-max(d - r, 0.0) * 2.5) * 0.38
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
