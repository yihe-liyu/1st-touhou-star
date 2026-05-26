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

## 滚动 Sprite3D 材质的 UV 偏移
## _process 会随暂停停止 → 自动适配暂停 ✅
func _apply_scroll(delta: float):
	if scroll_speed == Vector2.ZERO:
		return
	for child in get_children():
		if child is Sprite3D:
			var mat := child.material_override as StandardMaterial3D
			if not mat:
				mat = StandardMaterial3D.new()
				mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED  # 不受光照，直接显示贴图颜色
				if child.texture:
					mat.albedo_texture = child.texture
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
