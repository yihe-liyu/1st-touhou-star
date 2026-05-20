extends Node

signal wave_started(wave_index: int)
signal wave_cleared(wave_index: int)
signal stage_cleared(stage_id: int)
signal all_enemies_defeated()

var current_level: LevelData
var _wave_index: int = -1
var _stage_active: bool = false
var _wave_timer: float = 0.0
var _wave_active: bool = false
var _spawned_in_wave: int = 0
var _defeated_in_wave: int = 0
var _waiting_for_spawn: bool = false
var _spawn_delay_remaining: float = 0.0

func load_stage(data: LevelData):
	if _stage_active:
		stop_stage()

	current_level = data
	_wave_index = -1
	_stage_active = true
	GameState.reset_score()
	_advance_wave()

func stop_stage():
	_stage_active = false
	_wave_active = false
	_waiting_for_spawn = false
	current_level = null
	_wave_index = -1
	_spawned_in_wave = 0
	_defeated_in_wave = 0

func _ready():
	if not GameEvents.enemy_killed.is_connected(_on_enemy_killed):
		GameEvents.enemy_killed.connect(_on_enemy_killed)

func _process(delta):
	if not _stage_active:
		return
	if GameManager.current_state != GameManager.AppState.PLAYING:
		return

	if _wave_active:
		_wave_timer += delta

	if _waiting_for_spawn:
		_spawn_delay_remaining -= delta
		if _spawn_delay_remaining <= 0.0:
			_waiting_for_spawn = false
			_do_spawn()

func _advance_wave():
	_wave_index += 1
	if _wave_index >= current_level.waves.size():
		_stage_active = false
		_wave_active = false
		stage_cleared.emit(current_level.stage_id)
		GameState.save_high_score(current_level.stage_id, GameState.current_score)
		return

	_wave_active = true
	_wave_timer = 0.0
	_spawned_in_wave = 0
	_defeated_in_wave = 0
	wave_started.emit(_wave_index)

	var wave = current_level.waves[_wave_index]
	if wave.spawn_delay > 0.0:
		_waiting_for_spawn = true
		_spawn_delay_remaining = wave.spawn_delay
	else:
		_do_spawn()

func _do_spawn():
	var wave = current_level.waves[_wave_index]
	if not wave.enemy_data:
		_check_wave_complete()
		return

	var enemy_scene = load("res://scenes/enemy.tscn")
	var enemy = enemy_scene.instantiate()
	enemy.enemy_data = wave.enemy_data

	var parent = get_tree().current_scene
	if parent:
		var world = parent.get_node_or_null("World")
		if world:
			parent = world
	enemy.global_position = wave.spawn_position
	parent.add_child(enemy)

	_spawned_in_wave += 1

func _on_enemy_killed(_score: int, _position: Vector2):
	if not _stage_active or not _wave_active:
		return
	_defeated_in_wave += 1
	_check_wave_complete()

func _check_wave_complete():
	var wave = current_level.waves[_wave_index]
	if wave.trigger_condition == WaveData.TriggerCondition.ALL_DEFEATED:
		var alive = 0
		for e in GameState.active_enemies:
			if is_instance_valid(e):
				alive += 1
		if alive > 0:
			return

	wave_cleared.emit(_wave_index)
	_wave_active = false

	if _wave_index + 1 >= current_level.waves.size():
		all_enemies_defeated.emit()
		_advance_wave()
	else:
		await get_tree().create_timer(1.0).timeout
		if _stage_active:
			_advance_wave()
