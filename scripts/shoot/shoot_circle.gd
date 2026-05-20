extends ShootPatternBase
class_name ShootCircle

@export var bullet_count: int = 12
@export var speed_multiplier: float = 1.0
@export var offset_angle: float = 0.0

func make_override() -> BulletOverride:
	var ov = BulletOverride.new()
	ov.speed_mult = speed_multiplier
	return ov

func emit(shooter: Node2D, override: BulletOverride):
	for i in range(bullet_count):
		var angle = TAU / bullet_count * i + offset_angle
		var dir = Vector2.RIGHT.rotated(angle)
		BulletManager.shoot_enemy_bullet(bullet_data, shooter.global_position, dir, override)
