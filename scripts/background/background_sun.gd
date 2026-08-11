class_name BackgroundSun
extends Node3D

## 日食太阳组件：Sprite3D + 程序化圆盘纹理 + sun_sprite shader
## 由演出脚本调用 setup() 创建（practice 模式不调 → 无太阳，与旧行为一致）
## setup() 幂等：重复调用不重复创建（重跑安全）
## 圆盘纹理：预生成资源（sun_disc.tres），setup 即用 → 零生成等待/零卡顿
## 改纹理尺寸后重跑 tools/regenerate_fog_tex.gd

const SUN_DISC_PATH := "res://assets/Textures/background/stage01/sun_disc.tres"

@export var sun_position: Vector3 = Vector3(0, 100, -320)
@export var pixel_size: float = 0.31
@export var texture_size: int = 256          ## 圆盘纹理尺寸（预生成用）

var sprite: Sprite3D


func setup() -> void:
	if sprite:
		return
	position = sun_position
	var sun := Sprite3D.new()
	sun.name = "SunSprite"
	sun.pixel_size = pixel_size
	sun.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	var smat := ShaderMaterial.new()
	smat.shader = preload("res://gdshader/sun_sprite.gdshader")
	# 预生成纹理：毫秒级就绪，太阳一次性完整出现
	var img: Image = load(SUN_DISC_PATH)
	if img == null:
		push_error("BackgroundSun: 预生成纹理缺失，请运行 tools/regenerate_fog_tex.gd；本次用同步生成兜底")
		img = _make_sun_disc(texture_size)
	var tex := ImageTexture.create_from_image(img)
	sun.texture = tex
	smat.set_shader_parameter("sun_tex", tex)
	sun.material_override = smat
	add_child(sun)
	sprite = sun


## 规则圆太阳纹理：中心亮暖白、边缘柔和、外圈光晕——干净的正圆（黑雾层负责遮）
## 供预生成工具 tools/regenerate_fog_tex.gd 使用
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
