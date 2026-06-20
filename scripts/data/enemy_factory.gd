class_name EnemyFactory
extends RefCounted
## 字典式敌人生成——零 .tres 零 .gd

const ENEMY_SCENE = preload("res://scenes/enemy.tscn")


func spawn(_ctx: StageContext, visual_key: String, move_cfg: Dictionary, shoot_cfg: Dictionary, pos: Vector2, opts: Dictionary = {}) -> Enemy:
	var e := ENEMY_SCENE.instantiate()
	
	# 外观
	var vis_res := AssetRegistry.enemy_visuals.get(visual_key)
	if vis_res:
		e.add_child(vis_res.instantiate())
	
	# EnemyData（最小）
	var data := EnemyData.new()
	data.max_hp = opts.get("hp", 100)
	data.hitbox_radius = opts.get("hitbox", 8.0)
	data.item_power = opts.get("drop_power", 1)
	data.item_point = opts.get("drop_point", 2)
	data.death_effect = AssetRegistry.enemy_visuals.get("death")
	e.enemy_data = data
	e.global_position = pos
	
	# 移动
	_attach_move(e, move_cfg)
	
	# 弹幕
	_attach_shoot(e, shoot_cfg)
	
	return e


func _attach_move(enemy: Enemy, cfg: Dictionary) -> void:
	if cfg.is_empty(): return
	var pat_key: String = cfg.get("type", "")
	var script: Script = AssetRegistry.patterns.get(pat_key)
	if not script: return
	
	var ms: Node = script.new()
	if not ms is MoveScript: return
	
	for key in cfg:
		if key != "type" and key in ms:
			ms.set(key, cfg[key])
	
	enemy.add_child(ms)
	var move_ctx := StageContext.new(ms)
	ms.start_moving(move_ctx, enemy)


func _attach_shoot(enemy: Enemy, cfg: Dictionary) -> void:
	if cfg.is_empty(): return
	var pat_key: String = cfg.get("type", "")
	var script: Script = AssetRegistry.patterns.get(pat_key)
	if not script: return
	
	var cs: Node = script.new()
	if not cs is CreateScript: return
	
	# 先造子弹
	if cfg.has("bullet"):
		var bc: Dictionary = cfg["bullet"]
		var b := BulletData.new()
		var tex_path: String = AssetRegistry.bullet_textures.get(bc.get("tex", ""), "")
		if tex_path != "":
			b.texture = load(tex_path)
		b.velocity = Vector2(0, bc.get("speed", 400))
		b.tint = bc.get("color", Color.WHITE)
		b.faction = BulletData.Faction.ENEMY
		b.can_be_canceled = true
		cs.set("bullet", b)
	
	# 设其余字段
	for key in cfg:
		if key not in ["type", "bullet"] and key in cs:
			cs.set(key, cfg[key])
	
	# 音效
	if cfg.has("sfx"):
		var sfx_res: AudioStream = AssetRegistry.sounds.get(cfg["sfx"])
		if sfx_res:
			cs.set("sfx", sfx_res)
	
	enemy.add_child(cs)
	var shoot_ctx := StageContext.new(cs)
	cs.start_creating(shoot_ctx)
