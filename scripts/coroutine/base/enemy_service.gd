class_name EnemyService
extends RefCounted

var active: bool = true
var ctx: StageContext

const ENEMY_SCENE = preload("res://scenes/enemy.tscn")


func spawn_enemy(data: EnemyData, position: Vector2, auto_start: bool = true) -> Enemy:
	if not active: return null
	return StageManager.spawn_enemy(data, position, auto_start)

func spawn(key: String, pos: Vector2, params: Dictionary = {}) -> Enemy:
	if not active: return null
	var script: Script = AssetRegistry.enemies.get(key)
	if not script: return null
	
	var enemy := ENEMY_SCENE.instantiate()
	enemy.global_position = pos
	
	var ed := EnemyData.new()
	ed.max_hp = params.get("hp", 100)
	ed.hitbox_radius = params.get("hitbox", 8.0)
	ed.item_power = params.get("drop_power", 1)
	ed.item_point = params.get("drop_point", 2)
	ed.death_effect = AssetRegistry.enemy_visuals.get("death")
	enemy.enemy_data = ed
	
	var es: Node = script.new()
	var script_inst := es as EnemyScript
	if not script_inst:
		push_warning("EnemyService.spawn: script %s is not an EnemyScript" % key)
		enemy.queue_free()
		return null
	
	for k in params:
		if k in script_inst:
			script_inst.set(k, params[k])
	
	enemy.add_child(script_inst)
	script_inst.setup(enemy, ctx)
	script_inst.start()
	
	StageManager.add_enemy_to_scene(enemy)
	return enemy

func spawn_boss(data: BossData, position: Vector2) -> void:
	if not active: return
	StageManager.spawn_boss(data, position, false, ctx)

func all_defeated() -> bool:
	return GameState.active_enemies.is_empty()
