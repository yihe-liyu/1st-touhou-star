extends Node

const ENEMY_SCENE = preload("res://scenes/enemy.tscn")
const BossClass = preload("res://scripts/enemy/boss.gd")

signal stage_started()
signal stage_cleared()
signal all_enemies_defeated()

var current_stage: StageData
var current_background: StageBackground
var _stage_active: bool = false
var _stage_script: StageScript

func load_stage(data: StageData):
	if _stage_active:
		stop_stage()

	if not data.create_script:
		push_error("StageManager: StageData has no create_script")
		return

	GameState.reset_all()

	current_stage = data
	_stage_active = true

	var stage_script = data.create_script.new()
	assert(stage_script is StageScript, "StageManager: create_script must be a StageScript")
	add_child(stage_script)
	_stage_script = stage_script
	stage_script.finished.connect(_on_stage_finished)

	var ctx := StageContext.new(stage_script)
	stage_script.start_stage(ctx)

	# 自动启动背景场景里挂的所有 BackgroundScript
	if current_background:
		for child in current_background.get_children():
			if child is BackgroundScript:
				var bg_ctx := StageContext.new(child)
				child.start_background(bg_ctx)

	stage_started.emit()


func stop_stage():
	_stage_active = false
	current_stage = null
	current_background = null
	if _stage_script and is_instance_valid(_stage_script):
		_stage_script.stop()
		_stage_script.queue_free()
		_stage_script = null
	GameState.clear_enemies()
	BulletManager.clear_bullets()  # 清弹幕，激光自己淡出

func _on_stage_finished():
	if not current_stage:
		return
	_stage_active = false
	stage_cleared.emit()
	all_enemies_defeated.emit()
	GameState.save_high_score(current_stage.stage_id, GameState.current_score)

func spawn_enemy(data: EnemyData, position: Vector2, auto_start: bool = true) -> Enemy:
	var enemy = ENEMY_SCENE.instantiate()
	enemy.enemy_data = data
	enemy.global_position = position
	_add_enemy_to_scene(enemy)
	if auto_start:
		enemy.start.call_deferred()
	return enemy

func spawn_boss(data: BossData, position: Vector2, defer: bool = false, p_ctx: StageContext = null) -> Node:
	var boss := BossClass.new()
	boss.global_position = position
	if data.visual:
		var vis := data.visual.instantiate()
		boss.add_child(vis)
	_add_enemy_to_scene(boss)
	boss.setup(data, p_ctx)
	boss.start_boss(defer)
	return boss

func spawn_bullet(data: BulletData, position: Vector2, direction: Vector2) -> Bullet:
	return BulletManager.shoot_enemy_bullet(data, position, direction)

func _add_enemy_to_scene(node: Node2D):
	var parent = get_tree().current_scene
	if parent:
		var world = parent.get_node_or_null("World")
		if world:
			parent = world
	parent.add_child(node)
