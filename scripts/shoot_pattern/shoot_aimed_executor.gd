extends ShootExecutor
class_name ShootAimedExecutor

func _on_start():
	var def = current_def as ShootAimedDef
	_override.speed_mult = def.speed_multiplier

func _execute():
	var def = current_def as ShootAimedDef
	var player = GameState.player
	if not player:
		return

	var base_angle = target.global_position.direction_to(player.global_position).angle()
	base_angle += def.aim_offset

	var half_spread = def.spread_angle * 0.5
	var count = max(def.bullet_count, 1)

	if count == 1:
		var dir = Vector2.RIGHT.rotated(base_angle)
		shoot_enemy_bullet(dir)
		return

	for i in range(count):
		var t = float(i) / float(count - 1)
		var angle = base_angle - half_spread + def.spread_angle * t
		var dir = Vector2.RIGHT.rotated(angle)
		shoot_enemy_bullet(dir)
