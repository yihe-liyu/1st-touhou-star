class_name BackgroundScroll
extends Node3D

## 整体滚动速度（正值 = 向右/下）
@export var scroll_speed: Vector2 = Vector2(0, 0)

var _scroll_mult: float = 1.0


func _process(delta: float) -> void:
	var offset := scroll_speed * delta * _scroll_mult
	for child in get_children():
		if child is Node3D:
			child.position += Vector3(offset.x, offset.y, 0)


func set_scroll_mult(m: float) -> void:
	_scroll_mult = m
