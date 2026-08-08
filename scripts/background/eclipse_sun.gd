extends ColorRect
class_name EclipseSun
## 伪日食遮罩 —— CanvasItem shader（叠 3D 发光球上，摄像机平面）
## 黑色遮住太阳大部分光（"覆在眼睛上"），边缘一圈漏光
## set_glow(v)：0=日全食只剩轮廓 / 1=常态 / 2=回光

const SHADER = preload("res://gdshader/eclipse_sun.gdshader")

var glow: float = 1.0

func _init() -> void:
	size = Vector2(220, 220)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	material = ShaderMaterial.new()
	var m := material as ShaderMaterial
	m.shader = SHADER
	m.set_shader_parameter("radius", 0.30)  # 黑圆 132px ≈ 盖住 3D 球中心、边缘露一圈漏光
	set_glow(glow)

## 设置太阳中心位置（自动换算 rect 左上角）
func set_center(p: Vector2) -> void:
	position = p - size / 2.0

func set_glow(v: float) -> void:
	glow = clampf(v, 0.0, 2.5)
	if material is ShaderMaterial:
		(material as ShaderMaterial).set_shader_parameter("glow", glow)
