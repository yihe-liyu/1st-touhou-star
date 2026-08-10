extends CoroutineScript
## Stage01 背景演出 —— 时间线版

@onready var bg: StageBackground = $".."
@onready var ground: BackgroundPlane = $"../Ground"

const OAK_LAYER = preload("res://data/stages/stage01/background/oak.tres")

var _fog_rect: ColorRect = null
var _fog_mat: ShaderMaterial = null
var _fog_sun: Sprite3D = null


func _ready() -> void:
	_reset_environment()


func _reset_environment() -> void:
	if not bg.world_environment: return
	var env := bg.world_environment.environment
	env.fog_light_color = Color(0.18, 0.20, 0.23)  # 雾色=暗蓝灰雾：远处地面/树融进雾里而非黑色（原为纯黑→远区发黑）
	env.fog_density = 0.15  # 背景正常（日食感集中在太阳，不全局浓雾）
	# 程序化天空：微暗蒙眼的白天（伪日食下"黑蒙蒙的天"，但看得出是白天）
	var sky := ProceduralSkyMaterial.new()
	sky.sky_top_color = Color(0.20, 0.24, 0.30)       # 天顶：暗蓝灰
	sky.sky_horizon_color = Color(0.42, 0.44, 0.46)   # 地平线：稍亮
	sky.sky_curve = 0.35
	# 天空球地面色=雾色：平面边缘（z=-190）之外的区域显示天球地面色，
	# 必须与雾色一致，否则"地面没盖住"的地方露馅（与 fog_light_color 同步改）
	sky.ground_horizon_color = Color(0.18, 0.20, 0.23)
	sky.ground_bottom_color = Color(0.14, 0.15, 0.17)
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
		_fog_to(Color(0.18, 0.20, 0.23, 1.0), 0.04, 68.0, 12)
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
	# 全屏 2D 蒙眼雾层：盖整个游戏画面（背景+弹幕）——玩家被蒙眼
	_spawn_screen_fog(sun)


## 全屏蒙眼雾：CanvasLayer + ColorRect + canvas_item shader——背景的一部分（挂 bg，随背景销毁/重载）
## 只蒙背景层（弹幕保持清晰）；太阳屏幕位置处更浓（专门遮太阳）
func _spawn_screen_fog(sun: Sprite3D) -> void:
	if bg.get_node_or_null("EyeFogLayer"):
		return
	var layer := CanvasLayer.new()
	layer.name = "EyeFogLayer"
	layer.layer = 5  # 背景 SubViewport 内叠在 3D 之上
	bg.add_child(layer)
	var rect := ColorRect.new()
	rect.name = "FogRect"
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://gdshader/screen_fog.gdshader")
	mat.set_shader_parameter("noise_tex", _make_cloud_texture(256))
	layer.add_child(rect)
	rect.material = mat
	# 太阳 3D 位置 → 屏幕坐标（每帧更新：相机动太阳也跟着动）
	_fog_rect = rect
	_fog_mat = mat
	_fog_sun = sun


func _process(_delta: float) -> void:
	if not _fog_mat or not _fog_sun or not bg.camera:
		return
	var sp: Vector2 = bg.camera.unproject_position(_fog_sun.global_position)
	var vp: Vector2 = bg.get_viewport().get_visible_rect().size
	if vp.x > 0 and vp.y > 0:
		_fog_mat.set_shader_parameter("sun_pos", sp / vp)


## 值噪声云斑纹理（fbm 多频叠加，格点按周期取模 → 四方无缝可平铺）：有机雾斑，非正弦波浪
func _make_cloud_texture(size: int) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var layers: Array[int] = [6, 12, 24]
	var weights: Array[float] = [0.55, 0.30, 0.15]
	var noise_seed := 20240808
	for y in range(size):
		for x in range(size):
			var v := 0.0
			for i in layers.size():
				var f := float(layers[i]) / size
				v += _value_noise(x * f, y * f, layers[i], noise_seed + i) * weights[i]
			# 增强对比（云斑更分明）
			v = clampf((v - 0.5) * 1.8 + 0.5, 0.0, 1.0)
			img.set_pixel(x, y, Color(v, v, v, 1.0))
	return ImageTexture.create_from_image(img)


## 平滑值噪声：格点随机 + 双线性平滑插值；格点按 period 取模 → 纹理四方无缝
## （u/v 范围 [0, period)，晶格 0..period-1，邻居晶格 period 折回 0）
func _value_noise(u: float, v: float, period: int, s: int) -> float:
	var x0 := int(floor(u))
	var y0 := int(floor(v))
	var fx: float = u - floor(u)
	var fy: float = v - floor(v)
	fx = fx * fx * (3.0 - 2.0 * fx)
	fy = fy * fy * (3.0 - 2.0 * fy)
	var a := _noise_hash(x0 % period, y0 % period, s)
	var b := _noise_hash((x0 + 1) % period, y0 % period, s)
	var c := _noise_hash(x0 % period, (y0 + 1) % period, s)
	var d2 := _noise_hash((x0 + 1) % period, (y0 + 1) % period, s)
	return lerpf(lerpf(a, b, fx), lerpf(c, d2, fx), fy)


func _noise_hash(x: int, y: int, s: int) -> float:
	# sin 小数 hash（经典 GLSL 技巧）：无溢出、确定性、0~1
	var n: float = sin(float(x * 127.1 + y * 311.7 + s * 74.7)) * 43758.5453
	return n - floor(n)


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
