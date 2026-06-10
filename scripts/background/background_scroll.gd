class_name BackgroundScroll
extends Node3D

## 独立滚动速度（follow 为空时生效）
@export var scroll_speed: Vector3 = Vector3(0, 0, 0)

## 跟随节点 —— 拖入一个 BackgroundPlane，自动复用它的速度（XZ 方向）
@export var follow: BackgroundPlane

@export_group("自动生成")
## 装饰物原型（空 = 使用已有子节点）
@export var prefab: PackedScene
## 生成数量
@export var count: int = 0
## 每个实例之间的间距
@export var spacing: Vector3 = Vector3(100, 0, 0)
## 每实例随机偏移范围（±）
@export var random_offset: Vector3 = Vector3(0, 0, 0)

var _scroll_mult: float = 1.0


func _ready() -> void:
	if prefab and count > 0:
		for i in count:
			var inst := prefab.instantiate()
			var pos := spacing * i
			pos.x += randf_range(-random_offset.x, random_offset.x)
			pos.y += randf_range(-random_offset.y, random_offset.y)
			pos.z += randf_range(-random_offset.z, random_offset.z)
			inst.position = pos
			add_child(inst)


func _process(delta: float) -> void:
	var offset: Vector3
	if follow:
		# UV 速度 → 世界速度：plane_size / tiling 换算
		var ratio_x := follow.plane_size.x / follow.tiling.x if follow.tiling.x > 0 else 1.0
		var ratio_y := follow.plane_size.y / follow.tiling.y if follow.tiling.y > 0 else 1.0
		offset = Vector3(follow.scroll_speed.x * ratio_x, 0, -follow.scroll_speed.y * ratio_y) * delta * _scroll_mult
	else:
		offset = scroll_speed * delta * _scroll_mult
	for child in get_children():
		if child is Node3D:
			child.position += offset


func set_scroll_mult(m: float) -> void:
	_scroll_mult = m
