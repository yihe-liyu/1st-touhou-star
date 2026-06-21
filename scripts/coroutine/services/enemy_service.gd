class_name EnemyService
## 敌人生成服务
extends RefCounted

var active: bool = true
var ctx: StageContext

const ENEMY_SCENE = preload("res://scenes/enemy.tscn")


func spawn(key: String, pos: Vector2) -> EnemyData:
	## 返回 EnemyData 构造链，调 .spawn() 终结
	var ed := EnemyData.new()
	ed.death_effect = AssetRegistry.enemy_visuals.get("death")
	ed._spawn_meta = {"key": key, "pos": pos, "svc": self}
	return ed

func spawn_enemy(data: EnemyData, position: Vector2, auto_start: bool = true) -> Enemy:
	if not active: return null
	return StageManager.spawn_enemy(data, position, auto_start)

func spawn_boss(data: BossData, position: Vector2) -> void:
	if not active: return
	StageManager.spawn_boss(data, position, false, ctx)

func all_defeated() -> bool:
	return GameState.active_enemies.is_empty()


func _do_spawn(ed: EnemyData, pos: Vector2, key: String, params: Dictionary) -> Enemy:
	if not active: return null
	var script: Script = AssetRegistry.enemies.get(key)
	if not script: return null
	
	var enemy := ENEMY_SCENE.instantiate()
	enemy.global_position = pos
	enemy.enemy_data = ed
	
	var cs: CoroutineScript = script.new()
	if not cs:
		push_warning("EnemyService.spawn: %s is not a CoroutineScript" % key)
		enemy.queue_free()
		return null
	
	cs.target = enemy
	for k in params:
		cs.set(k, params[k])
	if cs.has_method("setup_custom"):
		cs.setup_custom(params)
	enemy.add_child(cs)
	cs.start(ctx, enemy)
	
	StageManager.add_enemy_to_scene(enemy)
	return enemy
