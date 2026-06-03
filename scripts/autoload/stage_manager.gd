extends Node

const ENEMY_SCENE = preload("res://scenes/enemy.tscn")

signal stage_started()
signal stage_cleared()
signal all_enemies_defeated()

var current_stage: StageData
var _stage_active: bool = false
var _stage_script: StageScript

func load_stage(data: StageData):
	if _stage_active:
		stop_stage()

	if not data.create_script:
		push_error("StageManager: StageData has no create_script")
		return

	# 预加载资源，让卡顿发生在黑场期间而非第一次发弹时
	_preload_stage_assets(data)
	
	current_stage = data
	_stage_active = true
	GameState.reset_score()

	var stage_script = data.create_script.new()
	add_child(stage_script)
	_stage_script = stage_script
	stage_script.finished.connect(_on_stage_finished)

	var api = StageAPI.new(stage_script)
	stage_script.start_stage(api)

	stage_started.emit()


func stop_stage():
	_stage_active = false
	current_stage = null
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

func spawn_enemy(data: EnemyData, position: Vector2) -> Enemy:
	var enemy = ENEMY_SCENE.instantiate()
	enemy.enemy_data = data
	enemy.global_position = position
	_add_enemy_to_scene(enemy)
	return enemy

func spawn_bullet(data: BulletData, position: Vector2, direction: Vector2) -> Bullet:
	return BulletManager.shoot_enemy_bullet(data, position, direction)

## 预加载关卡资源：遍历所有可能用到的贴图，提前加载到 GPU
func _preload_stage_assets(data: StageData) -> void:
	# 预加载关卡脚本的子弹/敌人数据中引用的贴图
	# 方法是遍历所有 Resource，touch 它们的 texture 属性
	# 最简单的：直接加载敌人贴图（最常卡的地方）
	ResourceLoader.load("res://assets/Textures/bullet/bullet1.png", "Texture2D")
	ResourceLoader.load("res://assets/Textures/enemy/enemy.png", "Texture2D")


func _add_enemy_to_scene(enemy: Enemy):
	var parent = get_tree().current_scene
	if parent:
		var world = parent.get_node_or_null("World")
		if world:
			parent = world
	parent.add_child(enemy)
