class_name BackgroundPlane
extends MeshInstance3D

## 平面大小（地面用 256×256，远景可用更小）
@export var plane_size: Vector2 = Vector2(256, 256)

## UV 重复次数
@export var tiling: Vector2 = Vector2(6, 6)

## 滚动速度（像素/秒，最终乘 delta）
@export var scroll_speed: Vector2 = Vector2(0, 1.0)

## 颜色叠加（白色 = 原图，变暗/变色用）
@export var modulate: Color = Color.WHITE

## 贴图（在 Inspector 拖入）
@export var base_texture: Texture2D

var _scroll_mult: float = 1.0


func _ready() -> void:
	var mesh := PlaneMesh.new()
	mesh.size = plane_size
	mesh.orientation = PlaneMesh.FACE_Z
	self.mesh = mesh

	var mat := ShaderMaterial.new()
	mat.shader = preload("res://gdshader/background_plane.gdshader")
	mat.set_shader_parameter("tiling", tiling)
	mat.set_shader_parameter("modulate", modulate)
	if base_texture:
		mat.set_shader_parameter("base_texture", base_texture)
	mat.set_shader_parameter("uv_offset", Vector2.ZERO)
	self.material_override = mat


func _process(delta: float) -> void:
	var mat := material_override as ShaderMaterial
	if not mat:
		return
	var raw := mat.get_shader_parameter("uv_offset")
	if raw == null:
		return
	var uv := Vector2.ZERO
	if raw is Vector2:
		uv = raw
	uv += scroll_speed * delta * _scroll_mult
	mat.set_shader_parameter("uv_offset", uv)


## 由 StageBackground 状态机调用，控制全局滚动倍率
func set_scroll_mult(m: float) -> void:
	_scroll_mult = m
