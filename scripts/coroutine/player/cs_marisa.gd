extends PlayerShootScript
class_name MarisaShoot

const BULLET = preload("res://data/bullet_data/player/marisa_main_bullet.tres")
const OPTION_VISUAL = preload("res://scripts/coroutine/player/base/option_visual.gd")

const MAIN_INTERVAL_LO: int = 5
const MAIN_INTERVAL_HI: int = 4
const OPTION_INTERVAL: int = 6


func _option_setup() -> Dictionary:
	return {
		visual_script = OPTION_VISUAL,
		power_thresholds = [0, 100, 200],
		counts = [0, 2, 4],
		offsets_focus = [
			[],
			[Vector2(-12, 0), Vector2(12, 0)],
			[Vector2(-25, -5), Vector2(-10, -5), Vector2(10, -5), Vector2(25, -5)],
		],
		offsets_spread = [
			[],
			[Vector2(-35, 0), Vector2(35, 0)],
			[Vector2(-60, 0), Vector2(-30, 15), Vector2(30, 15), Vector2(60, 0)],
		],
	}


func _main_shoot(_api: StageAPI, player: Player) -> float:
	var pw := GameState.power_raw
	if pw >= 200:
		ctx.bullets.shoot_spread(BULLET, 5, deg_to_rad(15), Vector2.UP, player.global_position)
		return ctx.clock.wait_frames(MAIN_INTERVAL_HI)
	elif pw >= 100:
		ctx.bullets.shoot_spread(BULLET, 3, deg_to_rad(10), Vector2.UP, player.global_position)
		return ctx.clock.wait_frames(MAIN_INTERVAL_LO)
	else:
		ctx.bullets.shoot_spread(BULLET, 1, 0.0, Vector2.UP, player.global_position + Vector2(-15, 0))
		ctx.bullets.shoot_spread(BULLET, 1, 0.0, Vector2.UP, player.global_position + Vector2(15, 0))
		return ctx.clock.wait_frames(MAIN_INTERVAL_LO)


func _option_shoot(api: StageAPI, _count: int) -> float:
	var pw := GameState.power_raw
	if pw >= 200:
		_shoot_options(api, BULLET, 3, deg_to_rad(8), Vector2.UP, Vector2.ZERO)
	elif pw >= 100:
		_shoot_options(api, BULLET, 1, 0.0, Vector2.UP, Vector2.ZERO)
	else:
		return 0.0
	return ctx.clock.wait_frames(OPTION_INTERVAL)
