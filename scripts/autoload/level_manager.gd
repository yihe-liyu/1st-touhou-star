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
var _current_wave_script: WaveScript

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
	for child in get_children():
		if child is WaveScript:
			child.stop()
	_current_wave_script = null
	current_level = null
	_wave_index = -1
	GameState.clear_enemies()
	BulletManager.clear_all()

func _process(_delta):
	pass

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
	wave_started.emit(_wave_index)

	var script_ref = null
	if "wave_script" in wave and wave.wave_script:
		script_ref = wave.wave_script
	elif "stage_script" in wave and wave.stage_script:
		script_ref = wave.stage_script

	if script_ref:
		var ws = script_ref.new()
		_current_wave_script = ws
		add_child(ws)
		var api = StageAPI.new(ws)
		ws.finished.connect(_advance_to_next_wave)
		ws.start_wave(api)
		return

	push_warning("LevelManager: wave %d has no script, skipping" % _wave_index)
	_advance_to_next_wave()

func _advance_to_next_wave():
	wave_cleared.emit(_wave_index)
	_wave_active = false
	if _wave_index + 1 >= current_level.waves.size():
		all_enemies_defeated.emit()
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

func _add_enemy_to_scene(enemy: Enemy):
	var parent = get_tree().current_scene
	if parent:
		var world = parent.get_node_or_null("World")
		if world:
			parent = world
	parent.add_child(enemy)
