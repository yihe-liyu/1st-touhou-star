class_name BackgroundScroll
extends Node3D

## 独立滚动速度（follow 为空时生效）
@export var scroll_speed: Vector2 = Vector2(0, 0)

## 跟随节点 —— 拖入一个 BackgroundPlane，自动复用它的速度
@export var follow: BackgroundPlane

var _scroll_mult: float = 1.0


func _process(delta: float) -> void:
	var speed := scroll_speed
	if follow:
		speed = follow.scroll_speed
	var offset := speed * delta * _scroll_mult
	for child in get_children():
		if child is Node3D:
			child.position += Vector3(offset.x, offset.y, 0)


func set_scroll_mult(m: float) -> void:
	_scroll_mult = m
