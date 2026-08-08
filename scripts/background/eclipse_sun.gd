extends ColorRect
class_name EclipseSun
## 伪日食太阳 —— CanvasItem shader（叠 3D 背景上，不受雾衰减）
## 不规则黑圆（noise 扰动边缘）+ 指数衰减金色漏光 + 日冕光晕
## set_glow(v)：0=全食只剩轮廓 / 1=常态 / 2=回光

const SHADER = preload("res://gdshader/eclipse_sun.gdshader")

var glow: float = 1.0

func _init() -> void:
	size = Vector2(200, 200)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	material = ShaderMaterial.new()
	(material as ShaderMaterial).shader = SHADER
	set_glow(glow)

## 设置太阳中心位置（自动换算 rect 左上角）
func set_center(p: Vector2) -> void:
	position = p - size / 2.0

func set_glow(v: float) -> void:
	glow = clampf(v, 0.0, 2.5)
	if material is ShaderMaterial:
		(material as ShaderMaterial).set_shader_parameter("glow", glow)
