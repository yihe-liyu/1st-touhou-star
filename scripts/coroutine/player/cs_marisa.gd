extends PlayerShootScript
class_name MarisaShoot

const BULLET = preload("res://data/bullet_data/marisa_main_bullet.tres")
const OPTION_VISUAL = preload("res://scripts/coroutine/player/base/option_visual.gd")

const SPREAD_2 = [Vector2(-35, 0), Vector2(35, 0)]
const FOCUS_2 = [Vector2(-12, 0), Vector2(12, 0)]
const SPREAD_4 = [Vector2(-60, 0), Vector2(-30, 15), Vector2(30, 15), Vector2(60, 0)]
const FOCUS_4 = [Vector2(-25, -5), Vector2(-10, -5), Vector2(10, -5), Vector2(25, -5)]

const MAIN_INTERVAL_LO: int = 5
const MAIN_INTERVAL_HI: int = 4
const OPTION_INTERVAL: int = 6

var _option_count: int = 0
var _option_spread: float = 0.0

func _on_run(api: StageAPI):
	await api.frames(1)
	run_parallel(_main_fire.bind(api))
	run_parallel(_option_fire.bind(api))

	while api._active():
		var p = api.get_player()
		if not is_instance_valid(p):
			await api.frames(1)
			continue

		var pw = GameState.power_raw
		var focused = Input.is_action_pressed("focus")

		var wanted := 0
		if pw >= 200:
			wanted = 4
		elif pw >= 100:
			wanted = 2

		var offsets: Array
		if wanted >= 4:
			offsets = FOCUS_4 if focused else SPREAD_4
		elif wanted >= 2:
			offsets = FOCUS_2 if focused else SPREAD_2
		else:
			offsets = []

		_sync_options(p, OPTION_VISUAL, wanted, offsets, api)

		if pw >= 200:
			_option_count = 3
			_option_spread = deg_to_rad(8)
		elif pw >= 100:
			_option_count = 1
			_option_spread = 0.0
		else:
			_option_count = 0

		await api.frames(1)

	_cleanup_options()

func _main_fire(api: StageAPI):
	while api._active():
		if not Input.is_action_pressed("shoot"):
			await api.frames(1)
			continue
		var player = api.get_player()
		if not is_instance_valid(player):
			await api.frames(1)
			continue

		var pw = GameState.power_raw
		if pw >= 200:
			api.shoot_spread(BULLET, 5, deg_to_rad(15), Vector2.UP, player.global_position)
			await api.frames(MAIN_INTERVAL_HI)
		elif pw >= 100:
			api.shoot_spread(BULLET, 3, deg_to_rad(10), Vector2.UP, player.global_position)
			await api.frames(MAIN_INTERVAL_LO)
		else:
			api.shoot_spread(BULLET, 1, 0.0, Vector2.UP, player.global_position + Vector2(-15, 0))
			api.shoot_spread(BULLET, 1, 0.0, Vector2.UP, player.global_position + Vector2(15, 0))
			await api.frames(MAIN_INTERVAL_LO)

func _option_fire(api: StageAPI):
	while api._active():
		if not Input.is_action_pressed("shoot"):
			await api.frames(1)
			continue
		if _option_count > 0 and _options.size() > 0:
			_shoot_options(api, BULLET, _option_count, _option_spread, Vector2.UP)
			await api.frames(OPTION_INTERVAL)
		else:
			await api.frames(1)
