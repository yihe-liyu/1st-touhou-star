extends ShootExecutor
class_name ShootCircleExecutor

func _on_start():
	var def = current_def as ShootCircleDef
	_override.speed_mult = def.speed_multiplier

func _execute():
	var def = current_def as ShootCircleDef
	for i in range(def.bullet_count):
		var angle = TAU / def.bullet_count * i + def.offset_angle
		var dir = Vector2.RIGHT.rotated(angle)
		shoot_enemy_bullet(dir )
