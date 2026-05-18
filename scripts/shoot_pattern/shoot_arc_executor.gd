extends ShootExecutor
class_name ShootArcExecutor

func _on_start():
	var def = current_def as ShootArcDef
	_override.speed_mult = def.speed_multiplier

func _execute():
	var def = current_def as ShootArcDef

	var center_angle: float
	if def.aim_at_player:
		var player = GameState.player
		if not player:
			return
		center_angle = target.global_position.direction_to(player.global_position).angle()
	else:
		center_angle = def.fixed_direction

	var half_arc = def.arc_angle * 0.5
	var count = max(def.bullet_count, 1)

	if count == 1:
		var dir = Vector2.RIGHT.rotated(center_angle)
		shoot_enemy_bullet(dir)
		return

	for i in range(count):
		var t = float(i) / float(count - 1)
		var angle = center_angle - half_arc + def.arc_angle * t
		var dir = Vector2.RIGHT.rotated(angle)
		shoot_enemy_bullet(dir)
