extends ShootPatternBase
class_name ShootArc

@export var bullet_count: int = 3
@export var arc_angle: float = 1.0
@export var aim_at_player: bool = true
@export var fixed_direction: float = 0.0
@export var speed_multiplier: float = 1.0

func make_override() -> BulletOverride:
	var ov = BulletOverride.new()
	ov.speed_mult = speed_multiplier
	return ov

func emit(shooter: Node2D, override: BulletOverride):
	var center_angle: float
	if aim_at_player:
		var player = GameState.player
		if not player:
			return
		center_angle = shooter.global_position.direction_to(player.global_position).angle()
	else:
		center_angle = fixed_direction

	var half_arc = arc_angle * 0.5
	var count = max(bullet_count, 1)

	if count == 1:
		var dir = Vector2.RIGHT.rotated(center_angle)
		BulletManager.shoot_enemy_bullet(bullet_data, shooter.global_position, dir, override)
		return

	for i in range(count):
		var t = float(i) / float(count - 1)
		var angle = center_angle - half_arc + arc_angle * t
		var dir = Vector2.RIGHT.rotated(angle)
		BulletManager.shoot_enemy_bullet(bullet_data, shooter.global_position, dir, override)
