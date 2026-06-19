extends PlayerShootScript
class_name ReimuShoot

const MAIN_BULLET = preload("res://data/player_data/bullet/reimu_main.tres")
const OPTION_BULLET_UNFOCUSED = preload("res://data/player_data/bullet/reimu_option01.tres")
const OPTION_BULLET_FOCUSED = preload("res://data/player_data/bullet/reimu_option02.tres")
const OPTION_VISUAL = preload("res://scripts/coroutine/player/ov_reimu.gd")

const MAIN_INTERVAL: int = 3


func _option_setup() -> Dictionary:
	return {
		visual_script = OPTION_VISUAL,
		power_thresholds = [0, 100, 200, 300],
		counts = [1, 2, 3, 4],
		offsets_focus = [
			[Vector2(0, 60)],
			[Vector2(-10, 60), Vector2(10, 60)],
			[Vector2(-20, 60), Vector2(0, 60), Vector2(20, 60)],
			[Vector2(-30, 60), Vector2(-10, 60), Vector2(10, 60), Vector2(30, 60)],
		],
		offsets_spread = [
			[Vector2(0, -80)],
			[Vector2(-40, -80), Vector2(40, -80)],
			[Vector2(-40, -60), Vector2(0, -80), Vector2(40, -60)],
			[Vector2(-60, -60), Vector2(-20, -80), Vector2(20, -80), Vector2(60, -60)],
		],
	}


func _main_shoot(_ctx: StageContext, player: Player) -> float:
	ctx.bullets.shoot_spread(MAIN_BULLET, 1, 0.0, Vector2.UP, player.global_position + Vector2(-20, 0))
	ctx.bullets.shoot_spread(MAIN_BULLET, 1, 0.0, Vector2.UP, player.global_position + Vector2(20, 0))
	return ctx.clock.wait_frames(MAIN_INTERVAL)


func _option_shoot(_ctx: StageContext, _count: int) -> float:
	if Input.is_action_pressed("focus"):
		_shoot_options(ctx, OPTION_BULLET_FOCUSED, 1, 0.0, Vector2.UP, Vector2(-7, 0))
		_shoot_options(ctx, OPTION_BULLET_FOCUSED, 1, 0.0, Vector2.UP, Vector2(7, 0))
		return ctx.clock.wait_frames(4)
	else:
		_shoot_options(ctx, OPTION_BULLET_UNFOCUSED, 1, 0.0, Vector2.UP, Vector2.ZERO)
		return ctx.clock.wait_frames(8)
