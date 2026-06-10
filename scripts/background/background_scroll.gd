class_name BackgroundScroll
extends Node3D

## 独立滚动速度（follow 为空时生效）
@export var scroll_speed: Vector3 = Vector3(0, 0, 0)

## 跟随节点 —— 拖入一个 BackgroundPlane，自动复用它的速度（XZ 方向）
@export var follow: BackgroundPlane

var _scroll_mult: float = 1.0


func _process(delta: float) -> void:
	var offset: Vector3
	if follow:
		offset = Vector3(follow.scroll_speed.x, 0, follow.scroll_speed.y) * delta * _scroll_mult
	else:
		offset = scroll_speed * delta * _scroll_mult
	for child in get_children():
		if child is Node3D:
			child.position += offset


func set_scroll_mult(m: float) -> void:
	_scroll_mult = m
