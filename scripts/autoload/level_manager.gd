extends Node

const ENEMY_SCENE = preload("res://scenes/enemy.tscn")

signal stage_started()
signal stage_cleared()
signal all_enemies_defeated()

var current_level: LevelData
var _level_script: LevelScript
var _stage_active: bool = false

func load_stage(data: LevelData):
	if _stage_active:
		stop_stage()

	if not data.create_script:
		push_error("LevelManager: LevelData has no create_script")
		return

	current_level = data
	_stage_active = true
	GameState.reset_score()

	stage_started.emit()

	var ls = data.create_script.new()
	_level_script = ls
	add_child(ls)
	ls.finished.connect(_on_level_finished)
	var api = StageAPI.new(ls)
	ls.start_level(api)

func stop_stage():
	_stage_active = false
	if _level_script and is_instance_valid(_level_script):
		_level_script.stop()
		_level_script.queue_free()
	_level_script = null
	current_level = null
	GameState.clear_enemies()
	BulletManager.clear_all()

func _on_level_finished():
	if not current_level:
		return
	stage_cleared.emit()
	all_enemies_defeated.emit()
	GameState.save_high_score(current_level.stage_id, GameState.current_score)

func spawn_enemy(data: EnemyData, pos: Vector2) -> Enemy:
	var enemy = ENEMY_SCENE.instantiate()
	enemy.enemy_data = data
	enemy.global_position = pos
	_add_enemy_to_scene(enemy)
	return enemy

func spawn_bullet(data: BulletData, pos: Vector2, dir: Vector2) -> Bullet:
	return BulletManager.shoot_enemy_bullet(data, pos, dir)

func _add_enemy_to_scene(enemy: Enemy):
	var parent = get_tree().current_scene
	if parent:
		var world = parent.get_node_or_null("World")
		if world:
			parent = world
	parent.add_child(enemy)
