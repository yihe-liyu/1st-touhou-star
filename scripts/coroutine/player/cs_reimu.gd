extends PlayerShootScript
class_name ReimuShoot

const MAIN_BULLET = preload("res://data/bullet_data/player/reimu_main_bullet.tres")
const OPTION_BULLET01 = preload("res://data/bullet_data/player/reimu_option_bullet01.tres")
const OPTION_BULLET02 = preload("res://data/bullet_data/player/reimu_option_bullet02.tres")
const OPTION_VISUAL = preload("res://scripts/coroutine/player/ov_reimu.gd")

const SPREAD_1 = [Vector2(0, -80)]
const FOCUS_1 = [Vector2(0, 60)]
const SPREAD_2 = [Vector2(-40, -80), Vector2(40, -80)]
const FOCUS_2 = [Vector2(-15, 60), Vector2(15, 60)]
const SPREAD_3 = [Vector2(-40, -60), Vector2(0, -80), Vector2(40, -60)]
const FOCUS_3 = [Vector2(-30, 60), Vector2(0, 60), Vector2(30, 60)]
const SPREAD_4 = [Vector2(-60, -60), Vector2(-20, -80), Vector2(20, -80), Vector2(60, -60)]
const FOCUS_4 = [Vector2(-45, 60), Vector2(-15, 60), Vector2(15, 60), Vector2(45, 60)]

const MAIN_INTERVAL: int = 3
const OPTION_INTERVAL01: int = 8
const OPTION_INTERVAL02: int = 4

var _phase: int = 0

func _on_step(api: StageAPI) -> Variant:
	match _phase:
		0:
			run_parallel(_main_step.bind(api))
			run_parallel(_option_step.bind(api))
			_phase = 1
			return true
		1:
			# 每帧同步僚机位置
			var player = api.get_player()
			if not is_instance_valid(player):
				return true

			var pw := GameState.power_raw
			var focused := Input.is_action_pressed("focus")

			var wanted := 0
			if pw >= 300:   wanted = 4
			elif pw >= 200: wanted = 3
			elif pw >= 100: wanted = 2
			elif pw >= 0:   wanted = 1

			var offsets: Array
			if wanted >= 4:
				offsets = FOCUS_4 if focused else SPREAD_4
			elif wanted >= 3:
				offsets = FOCUS_3 if focused else SPREAD_3
			elif wanted >= 2:
				offsets = FOCUS_2 if focused else SPREAD_2
			elif wanted >= 1:
				offsets = FOCUS_1 if focused else SPREAD_1

			_sync_options(player, OPTION_VISUAL, wanted, offsets, api)
			return true
		_:
			return false

func _main_step(api: StageAPI) -> Variant:
	if not Input.is_action_pressed("shoot"):
		return true  # 下帧再检查
	var player = api.get_player()
	if not is_instance_valid(player):
		return true
	api.shoot_spread(MAIN_BULLET, 1, 0.0, Vector2.UP, player.global_position + Vector2(-20, 0))
	api.shoot_spread(MAIN_BULLET, 1, 0.0, Vector2.UP, player.global_position + Vector2(20, 0))
	AudioManager.play_sfx(preload("res://assets/Sound/player_shoot.wav"))
	return api.frames(MAIN_INTERVAL)

func _option_step(api: StageAPI) -> Variant:
	if not Input.is_action_pressed("shoot"):
		return true
	if _options.size() > 0:
		if Input.is_action_pressed("focus"):
			_shoot_options(api, OPTION_BULLET02, 1, 0.0, Vector2.UP, Vector2(-7, 0))
			_shoot_options(api, OPTION_BULLET02, 1, 0.0, Vector2.UP, Vector2(7, 0))
			return api.frames(OPTION_INTERVAL02)
		else:
			_shoot_options(api, OPTION_BULLET01, 1, 0.0, Vector2.UP, Vector2.ZERO)
			return api.frames(OPTION_INTERVAL01)
	return true
