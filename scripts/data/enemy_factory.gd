class_name EnemyFactory
extends RefCounted

const ENEMY_SCENE = preload("res://scenes/enemy.tscn")


func spawn_script(ctx: StageContext, script: Script, pos: Vector2, params: Dictionary = {}) -> Enemy:
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
	if not script_inst: return enemy
	
	for key in params:
		if key in script_inst:
			script_inst.set(key, params[key])
	
	enemy.add_child(script_inst)
	script_inst.setup(enemy, ctx)
	script_inst.start()
	
	StageManager.add_enemy_to_scene(enemy)
	return enemy
