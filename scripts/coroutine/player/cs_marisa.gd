extends PlayerShootScript
class_name MarisaShoot

const BULLET = preload("res://data/bullet_data/player/marisa_main_bullet.tres")
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

var _phase: int = 0

func _on_step(api: StageAPI) -> Variant:
	match _phase:
		0:
			run_parallel(_main_step.bind(api))
			run_parallel(_option_step.bind(api))
			_phase = 1
			return true
		1:
			var p = api.get_player()
			if not is_instance_valid(p):
				return true

			var pw := GameState.power_raw
			var focused := Input.is_action_pressed("focus")

			var wanted := 0
			if pw >= 200: wanted = 4
			elif pw >= 100: wanted = 2

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

			return true
		_:
			return false

func _main_step(api: StageAPI) -> Variant:
	if not Input.is_action_pressed("shoot"):
		return true
	var player = api.get_player()
	if not is_instance_valid(player):
		return true

	var pw := GameState.power_raw
	if pw >= 200:
		api.shoot_spread(BULLET, 5, deg_to_rad(15), Vector2.UP, player.global_position)
		return api.frames(MAIN_INTERVAL_HI)
	elif pw >= 100:
		api.shoot_spread(BULLET, 3, deg_to_rad(10), Vector2.UP, player.global_position)
		return api.frames(MAIN_INTERVAL_LO)
	else:
		api.shoot_spread(BULLET, 1, 0.0, Vector2.UP, player.global_position + Vector2(-15, 0))
		api.shoot_spread(BULLET, 1, 0.0, Vector2.UP, player.global_position + Vector2(15, 0))
		return api.frames(MAIN_INTERVAL_LO)

func _option_step(api: StageAPI) -> Variant:
	if not Input.is_action_pressed("shoot"):
		return true
	if _option_count > 0 and _options.size() > 0:
		_shoot_options(api, BULLET, _option_count, _option_spread, Vector2.UP, Vector2.ZERO)
		return api.frames(OPTION_INTERVAL)
	return true
