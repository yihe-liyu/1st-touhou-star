extends Node
## 关卡生命周期管理：加载/停止关卡，生成敌人/Boss

const ENEMY_SCENE = preload("res://scenes/enemy.tscn")
const BossClass = preload("res://scripts/enemy/boss.gd")

signal stage_started()
signal stage_cleared()
signal all_enemies_defeated()

var current_stage: StageData
var current_background: StageBackground
var _stage_active: bool = false
var _stage_script: CoroutineScript

## 当前关卡协程脚本（工作台/调试读取运行时间用）
func current_stage_script() -> CoroutineScript:
	return _stage_script

func load_stage(data: StageData):
	if _stage_active:
		stop_stage()

	# 配置校验：非法数据拒绝启动，防止除零/空脚本崩溃
	var errs := data.validate()
	for e in errs:
		push_error("StageManager 配置错误: " + e)
	if not errs.is_empty():
		return

	GameState.reset_all()

	current_stage = data
	_stage_active = true

	var stage_script: CoroutineScript = data.create_script.new()
	assert(stage_script is CoroutineScript, "StageManager: create_script must be a CoroutineScript")
	add_child(stage_script)
	_stage_script = stage_script
	stage_script.finished.connect(_on_stage_finished)

	var ctx := StageContext.new(stage_script)
	stage_script.start(ctx)
	_inject_player_ctx(ctx)

	# 自动启动背景场景里挂的所有协程脚本
	if current_background:
		for child in current_background.get_children():
			if child is CoroutineScript:
				child.start(StageContext.new(child))

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

## 从 EnemyData 生成敌人（实例化/挂载协程/入场景）
func spawn_enemy_data(data: EnemyData, p_ctx: StageContext = null) -> Enemy:
	if not p_ctx or not p_ctx.active():
		return null
	if not data.has_script():
		push_warning("StageManager.spawn_enemy_data: no script set")
		return null
	var enemy: Enemy = ENEMY_SCENE.instantiate()
	enemy.global_position = data.get_spawn_pos()
	enemy.enemy_data = data
	enemy.ctx = p_ctx
	var cs: CoroutineScript = data.make_script()
	if not cs:
		push_warning("StageManager.spawn_enemy_data: script is not a CoroutineScript")
		enemy.queue_free()
		return null
	cs.target = enemy
	var params: Dictionary = data.get_params()
	for k in params:
		cs.set(k, params[k])
	if cs.has_method("setup_custom"):
		cs.setup_custom(params)
	enemy.add_child(cs)
	cs.start(p_ctx, enemy)
	add_enemy_to_scene(enemy)
	return enemy


func spawn_enemy(data: EnemyData, position: Vector2, auto_start: bool = true) -> Enemy:
	var enemy: Enemy = ENEMY_SCENE.instantiate()
	enemy.enemy_data = data
	enemy.global_position = position
	add_enemy_to_scene(enemy)
	if auto_start:
		enemy.start.call_deferred()
	return enemy

func spawn_boss(data: BossData, position: Vector2, p_ctx: StageContext = null) -> Node:
	var boss := BossClass.new()
	boss.global_position = position
	if data.visual:
		var vis := data.visual.instantiate()
		boss.add_child(vis)
	add_enemy_to_scene(boss)
	boss.setup(data, p_ctx)
	boss.start_boss()
	return boss

func spawn_bullet(data: BulletData, position: Vector2, direction: Vector2) -> Bullet:
	return BulletManager.shoot_enemy_bullet(data, position, direction)

## 把关卡上下文注入给场景中的自机（供系统操作服务）
func _inject_player_ctx(p_ctx: StageContext) -> void:
	var scene := get_tree().current_scene
	if not scene: return
	var player := scene.get_node_or_null("World/Player") as Player
	if player:
		player.ctx = p_ctx


func add_enemy_to_scene(node: Node2D):
	var parent: Node = get_tree().current_scene
	if parent:
		var world = parent.get_node_or_null("World")
		if world:
			parent = world
	parent.add_child(node)
