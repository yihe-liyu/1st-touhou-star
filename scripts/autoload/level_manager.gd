extends Node

const ENEMY_SCENE = preload("res://scenes/enemy.tscn")

signal wave_started(wave_index: int)
signal wave_cleared(wave_index: int)
signal stage_cleared(stage_id: int)
signal all_enemies_defeated()

var current_level: LevelData
var _wave_index: int = -1
var _stage_active: bool = false
var _wave_active: bool = false
var _wave_timer: float = 0.0
var _waiting_for_spawn: bool = false
var _spawn_delay_remaining: float = 0.0

var _spawned_in_wave: int = 0
var _defeated_in_wave: int = 0
var _spawns_remaining: int = 0
var _spawn_interval_timer: float = 0.0

func load_stage(data: LevelData):
	if _stage_active:
		stop_stage()

	if data.waves.size() == 0:
		push_warning("LevelManager: LevelData has no waves, not starting")
		return

	current_level = data
	_wave_index = -1
	_stage_active = true
	GameState.reset_score()
	_advance_wave()

func stop_stage():
	_stage_active = false
	_wave_active = false
	_waiting_for_spawn = false
	_spawn_interval_timer = 0.0
	_spawns_remaining = 0
	current_level = null
	_wave_index = -1
	_spawned_in_wave = 0
	_defeated_in_wave = 0
	GameState.clear_enemies()
	BulletManager.clear_all()

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
		var wave = current_level.waves[_wave_index]
		if wave.trigger_condition == WaveData.TriggerCondition.TIMED:
			if _wave_timer >= wave.trigger_time:
				_advance_to_next_wave()
				return

	if _waiting_for_spawn:
		_spawn_delay_remaining -= delta
		if _spawn_delay_remaining <= 0.0:
			_waiting_for_spawn = false
			_do_spawn()
		return

	if _spawn_interval_timer > 0.0:
		_spawn_interval_timer -= delta
		if _spawn_interval_timer <= 0.0:
			_do_spawn()

func _advance_wave():
	_wave_index += 1
	if _wave_index >= current_level.waves.size():
		_stage_active = false
		_wave_active = false
		stage_cleared.emit(current_level.stage_id)
		GameState.save_high_score(current_level.stage_id, GameState.current_score)
		return

	var wave = current_level.waves[_wave_index]
	_wave_active = true
	_wave_timer = 0.0
	_spawned_in_wave = 0
	_defeated_in_wave = 0
	_spawns_remaining = wave.spawn_count
	_spawn_interval_timer = 0.0
	wave_started.emit(_wave_index)

	if wave.stage_script:
		var controller = wave.stage_script.new()
		add_child(controller)
		controller.start(self, wave)
		return

	if wave.spawn_delay > 0.0:
		_waiting_for_spawn = true
		_spawn_delay_remaining = wave.spawn_delay
	else:
		_do_spawn()

func _do_spawn():
	var wave = current_level.waves[_wave_index]
	if not wave.enemy_data:
		push_warning("LevelManager: wave %d has no enemy_data, skipping" % _wave_index)
		_advance_to_next_wave()
		return

	var enemy = _spawn_one(wave)
	_add_enemy_to_scene(enemy)
	_spawned_in_wave += 1
	_spawns_remaining -= 1

	if _spawns_remaining > 0:
		if wave.spawn_interval > 0.0:
			_spawn_interval_timer = wave.spawn_interval
		else:
			while _spawns_remaining > 0:
				_add_enemy_to_scene(_spawn_one(wave))
				_spawned_in_wave += 1
				_spawns_remaining -= 1

func _spawn_one(wave: WaveData) -> Enemy:
	var enemy = ENEMY_SCENE.instantiate()
	enemy.enemy_data = wave.enemy_data

	var pos: Vector2
	if wave.spawn_positions.size() > 0:
		var idx = _spawned_in_wave % wave.spawn_positions.size()
		pos = wave.spawn_positions[idx]
	else:
		pos = wave.spawn_position

	if wave.move_pattern:
		var mover = wave.move_pattern.new()
		enemy.add_child(mover)

	enemy.global_position = pos
	return enemy

func _add_enemy_to_scene(enemy: Enemy):
	var parent = get_tree().current_scene
	if parent:
		var world = parent.get_node_or_null("World")
		if world:
			parent = world
	parent.add_child(enemy)

func _on_enemy_killed(_score: int, _position: Vector2):
	if not _stage_active or not _wave_active:
		return
	_defeated_in_wave += 1
	_check_wave_complete()

func _check_wave_complete():
	if not _wave_active:
		return
	var wave = current_level.waves[_wave_index]
	if wave.stage_script:
		return
	if wave.trigger_condition == WaveData.TriggerCondition.TIMED:
		return

	var alive = 0
	for e in GameState.active_enemies:
		if is_instance_valid(e):
			alive += 1
	if alive > 0:
		return

	_advance_to_next_wave()

func _advance_to_next_wave():
	wave_cleared.emit(_wave_index)
	_wave_active = false
	_spawn_interval_timer = 0.0

	if _wave_index + 1 >= current_level.waves.size():
		all_enemies_defeated.emit()
		_advance_wave()
	else:
		await get_tree().create_timer(1.0).timeout
		if _stage_active:
			_advance_wave()

func spawn_enemy(data: EnemyData, pos: Vector2) -> Enemy:
	var enemy = ENEMY_SCENE.instantiate()
	enemy.enemy_data = data
	enemy.global_position = pos
	_add_enemy_to_scene(enemy)
	return enemy

func spawn_bullet(data: BulletData, pos: Vector2, dir: Vector2) -> Bullet:
	return BulletManager.shoot_enemy_bullet(data, pos, dir)

func get_wave() -> WaveData:
	if current_level and _wave_index >= 0 and _wave_index < current_level.waves.size():
		return current_level.waves[_wave_index]
	return null

func force_advance():
	if not _stage_active or not _wave_active:
		return
	_advance_to_next_wave()
