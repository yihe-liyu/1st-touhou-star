class_name BackgroundCylinder
extends MeshInstance3D

## 圆柱半径（越大越环绕）
@export var radius: float = 200.0

## 圆柱高度
@export var height: float = 100.0

## UV 水平重复次数（U = 环绕方向）
@export var tiling_u: float = 4.0

## UV 垂直重复次数（V = 高度方向）
@export var tiling_v: float = 1.0

## 水平滚动速度（正值 = 贴图向右环绕）
@export var scroll_speed: float = 0.05

## 颜色叠加
@export var modulate: Color = Color.WHITE

## 贴图
@export var base_texture: Texture2D

var _scroll_mult: float = 1.0


func _ready() -> void:
	if not mesh:
		var cylinder_mesh := CylinderMesh.new()
		cylinder_mesh.top_radius = radius
		cylinder_mesh.bottom_radius = radius
		cylinder_mesh.height = height
		
		var mat := ShaderMaterial.new()
		mat.shader = preload("res://gdshader/background_cylinder.gdshader")
		mat.set_shader_parameter("tiling", Vector2(tiling_u, tiling_v))
		mat.set_shader_parameter("modulate", modulate)
		if base_texture:
			mat.set_shader_parameter("base_texture", base_texture)
		mat.set_shader_parameter("uv_offset", Vector2.ZERO)
		
		cylinder_mesh.material = mat
		self.mesh = cylinder_mesh
		return
	
	var mat := _get_material()
	if mat:
		mat.set_shader_parameter("tiling", Vector2(tiling_u, tiling_v))
		mat.set_shader_parameter("modulate", modulate)
		if base_texture:
			mat.set_shader_parameter("base_texture", base_texture)
		mat.set_shader_parameter("uv_offset", Vector2.ZERO)


func _process(delta: float) -> void:
	var mat := _get_material()
	if not mat:
		return
	var uv: Vector2 = mat.get_shader_parameter("uv_offset")
	uv.x += scroll_speed * delta * _scroll_mult
	mat.set_shader_parameter("uv_offset", uv)


func _get_material() -> ShaderMaterial:
	var cm := mesh as CylinderMesh
	if cm and cm.material is ShaderMaterial:
		return cm.material
	if material_override is ShaderMaterial:
		return material_override
	return null


func set_scroll_mult(m: float) -> void:
	_scroll_mult = m
