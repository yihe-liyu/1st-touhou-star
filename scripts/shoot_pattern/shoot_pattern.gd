# shoot_pattern.gd — DEPRECATED: Use ShootPatternDef + ShootExecutor instead.
extends Resource
class_name ShootPattern

var enemy: Enemy

func bind(e: Enemy):
	enemy = e

## 每帧调用，由 Enemy 的 _process 驱动
func update(_delta: float):
	pass
