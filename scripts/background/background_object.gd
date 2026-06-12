class_name BackgroundObject
extends Node3D

## 独立滚动速度（follow 为空时生效）
@export var scroll_speed: Vector3 = Vector3.ZERO

## 跟随地面 —— 拖 BackgroundPlane，自动同步 UV 滚动对应的世界速度
@export var follow: BackgroundPlane

var _scroll_mult: float = 1.0


func _process(delta: float) -> void:
	var offset: Vector3
	if follow:
		var ratio_x := follow.plane_size.x / follow.tiling.x if follow.tiling.x > 0 else 1.0
		var ratio_y := follow.plane_size.y / follow.tiling.y if follow.tiling.y > 0 else 1.0
		offset = Vector3(follow.scroll_speed.x * ratio_x, 0, -follow.scroll_speed.y * ratio_y) * delta * _scroll_mult
	else:
		offset = scroll_speed * delta * _scroll_mult
	position += offset
	# 超出视野自动回收
	if position.z > 50:
		queue_free()


func set_scroll_mult(m: float) -> void:
	_scroll_mult = m
