extends PlayerShootScript
class_name ReimuShoot

const MAIN_BULLET = preload("res://data/bullet_data/player/reimu_main_bullet.tres")
const OPTION_BULLET01 = preload("res://data/bullet_data/player/reimu_option_bullet01.tres")
const OPTION_BULLET02 = preload("res://data/bullet_data/player/reimu_option_bullet02.tres")
const OPTION_VISUAL = preload("res://scripts/coroutine/player/ov_reimu.gd")

const SPREAD_1 = [Vector2(0, -60)]
const FOCUS_1 = [Vector2(0, 60)]
const SPREAD_2 = [Vector2(-40, -60), Vector2(40, -60)]
const FOCUS_2 = [Vector2(-15, 60), Vector2(15, 60)]
const SPREAD_4 = [Vector2(-70, 0), Vector2(-35, 20), Vector2(35, 20), Vector2(70, 0)]
const FOCUS_4 = [Vector2(-30, -5), Vector2(-12, -5), Vector2(12, -5), Vector2(30, -5)]

func _on_run(api: StageAPI):
	await api.frames(1)
	while api._active():
		var player = api.get_player()
		if not is_instance_valid(player):
			await api.frames(1)
			continue

		var pw = GameState.power_raw
		var focused = Input.is_action_pressed("focus")
		var shooting = Input.is_action_pressed("shoot")

		var wanted := 0
		if pw >= 200:
			wanted = 4
		elif pw >= 100:
			wanted = 2
		elif pw >= 0:
			wanted = 1

		var offsets: Array
		if wanted >= 4:
			offsets = FOCUS_4 if focused else SPREAD_4
		elif wanted >= 2:
			offsets = FOCUS_2 if focused else SPREAD_2
		elif wanted >= 1:
			offsets = FOCUS_1 if focused else SPREAD_1

		_sync_options(player, OPTION_VISUAL, wanted, offsets, api)

		if shooting:
			api.shoot_spread(MAIN_BULLET, 1, 0.0, Vector2.UP, player.global_position + Vector2(-20, 0))
			api.shoot_spread(MAIN_BULLET, 1, 0.0, Vector2.UP, player.global_position + Vector2(20, 0))
			if pw < 100:
				_shoot_options(api, OPTION_BULLET01, 1, 0.0, Vector2.UP)
				await api.frames(5)
			elif pw < 200:
				_shoot_options(api, OPTION_BULLET01, 1, 0.0, Vector2.UP)
				await api.frames(5)
			else:
				_shoot_options(api, OPTION_BULLET02, 3, deg_to_rad(10), Vector2.UP)
				await api.frames(4)
		else:
			await api.frames(1)

	_cleanup_options()
