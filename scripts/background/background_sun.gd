class_name BackgroundSun
extends Node3D

## 日食太阳组件：Sprite3D + 程序化圆盘纹理 + sun_sprite shader
## 由演出脚本调用 setup() 创建（practice 模式不调 → 无太阳，与旧行为一致）
## setup() 幂等：重复调用不重复创建（重跑安全）
## 圆盘纹理后台线程生成（256² 不阻塞主线程，进关卡不卡）

@export var sun_position: Vector3 = Vector3(0, 100, -320)
@export var pixel_size: float = 0.31
@export var texture_size: int = 256

var sprite: Sprite3D
var _thread: Thread
var _tex_ready: bool = false


func setup() -> void:
	if sprite or _thread:
		return
	position = sun_position
	var sun := Sprite3D.new()
	sun.name = "SunSprite"
	sun.pixel_size = pixel_size
	sun.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sun.visible = false  # 纹理就绪前隐藏（避免白色块闪一下）
	var smat := ShaderMaterial.new()
	smat.shader = preload("res://gdshader/sun_sprite.gdshader")
	sun.material_override = smat
	add_child(sun)
	sprite = sun
	_thread = Thread.new()
	_thread.start(_make_sun_disc.bind(texture_size))


func _process(_delta: float) -> void:
	if _thread and not _thread.is_alive():
		var img: Image = _thread.wait_to_finish()
		_thread = null
		var tex := ImageTexture.create_from_image(img)
		sprite.texture = tex
		(sprite.material_override as ShaderMaterial).set_shader_parameter("sun_tex", tex)
		sprite.visible = true
		_tex_ready = true


func _exit_tree() -> void:
	if _thread and _thread.is_alive():
		_thread.wait_to_finish()
	_thread = null


## 规则圆太阳纹理：中心亮暖白、边缘柔和、外圈光晕——干净的正圆（黑雾层负责遮）
## 线程安全：纯函数 + 局部数据
func _make_sun_disc(size: int) -> Image:
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
	return img
