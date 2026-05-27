extends Node3D
class_name BackgroundLayer

## 滚动速度（UV 单位/秒）。1.0 = 每秒滚过一个完整纹理
## 只滚动 Y 轴（纵卷轴），正数 = 向下滚
@export var scroll_speed: Vector2 = Vector2.ZERO

var _background: StageBackground

func _ready():
	_background = _find_background()
	_on_setup()

func _process(delta):
	if not _background:
		return
	if not _background._active:
		return
	
	_apply_scroll(delta)
	_on_update(delta, _background._elapsed)

## 滚动 MeshInstance3D 材质的 UV 偏移
## _process 会随暂停停止 → 自动适配暂停 ✅
func _apply_scroll(delta: float):
	if scroll_speed == Vector2.ZERO:
		return
	for child in get_children():
		if child is MeshInstance3D:
			var mat: StandardMaterial3D = child.material_override as StandardMaterial3D
			if not mat:
				mat = StandardMaterial3D.new()
				mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				# 从 mesh 材质复制贴图
				var mesh_inst: MeshInstance3D = child as MeshInstance3D
				if mesh_inst.mesh and mesh_inst.mesh.material:
					var src_mat = mesh_inst.mesh.material
					if src_mat is BaseMaterial3D:
						mat.albedo_texture = src_mat.albedo_texture
				child.material_override = mat
			mat.uv1_offset += Vector3(scroll_speed.x * delta, scroll_speed.y * delta, 0.0)

func _find_background() -> StageBackground:
	var parent = get_parent()
	if parent is StageBackground:
		return parent
	if parent and parent.get_parent() is StageBackground:
		return parent.get_parent()
	return null

func _on_setup():
	pass

func _on_update(_delta: float, _elapsed: float):
	pass
