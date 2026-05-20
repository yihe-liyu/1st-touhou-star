extends Resource
class_name ShootPatternBase

@export var bullet_data: BulletData
@export var interval: float = 0.1
@export var duration: float = -1.0
@export var next_pattern: ShootPatternBase

func make_override() -> BulletOverride:
	return BulletOverride.new()

func emit(_shooter: Node2D, _override: BulletOverride):
	pass
