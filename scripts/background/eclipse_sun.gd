extends ColorRect
class_name EclipseSun
## 伪日食遮罩（摄像机平面黑圆）——CanvasItem shader，盖住 3D 太阳光斑中心
## set_glow(v)：0=日全食只剩轮廓 / 1=常态 / 2=回光

const SHADER = preload("res://gdshader/eclipse_sun.gdshader")

var glow: float = 1.0

func _init() -> void:
	size = Vector2(240, 240)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	material = ShaderMaterial.new()
	(material as ShaderMaterial).shader = SHADER
	set_glow(glow)

func set_center(p: Vector2) -> void:
	position = p - size / 2.0

func set_glow(v: float) -> void:
	glow = clampf(v, 0.0, 2.5)
	if material is ShaderMaterial:
		(material as ShaderMaterial).set_shader_parameter("glow", glow)
