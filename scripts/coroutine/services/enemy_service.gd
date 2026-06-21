class_name EnemyService
## 敌人生成服务
extends RefCounted

var active: bool = true
var ctx: StageContext

const ENEMY_SCENE = preload("res://scenes/enemy.tscn")


func spawn(key: String, pos: Vector2) -> SpawnConfig:
	return SpawnConfig.new(self, key, pos, ctx)

func spawn_enemy(data: EnemyData, position: Vector2, auto_start: bool = true) -> Enemy:
	if not active: return null
	return StageManager.spawn_enemy(data, position, auto_start)

func spawn_boss(data: BossData, position: Vector2) -> void:
	if not active: return
	StageManager.spawn_boss(data, position, false, ctx)

func all_defeated() -> bool:
	return GameState.active_enemies.is_empty()


func _spawn(key: String, pos: Vector2, p_ctx: StageContext, config: Dictionary, params: Dictionary) -> Enemy:
	if not active: return null
	var script: Script = AssetRegistry.enemies.get(key)
	if not script: return null
	
	var enemy := ENEMY_SCENE.instantiate()
	enemy.global_position = pos
	
	var ed := EnemyData.new()
	for k in config:
		ed.set(k, config[k])
	ed.death_effect = AssetRegistry.enemy_visuals.get("death")
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
	cs.start(p_ctx, enemy)
	
	StageManager.add_enemy_to_scene(enemy)
	return enemy


class SpawnConfig:
	extends RefCounted
	## .hp(200).power(2).param("bullet_speed", 400).spawn()
	
	var _svc: EnemyService
	var _key: String
	var _pos: Vector2
	var _ctx: StageContext
	var _config: Dictionary = {}
	var _params: Dictionary = {}
	
	func _init(svc: EnemyService, key: String, pos: Vector2, p_ctx: StageContext):
		_svc = svc; _key = key; _pos = pos; _ctx = p_ctx
	
	func hp(v: int) -> SpawnConfig:         _config["max_hp"] = v; return self
	func hitbox(v: float) -> SpawnConfig:   _config["hitbox_radius"] = v; return self
	func power(v: int) -> SpawnConfig:      _config["item_power"] = v; return self
	func point(v: int) -> SpawnConfig:      _config["item_point"] = v; return self
	func life(v: int) -> SpawnConfig:       _config["item_life"] = v; return self
	func bomb(v: int) -> SpawnConfig:       _config["item_bomb"] = v; return self
	func life_full(v: int) -> SpawnConfig:  _config["item_life_full"] = v; return self
	func bomb_full(v: int) -> SpawnConfig:  _config["item_bomb_full"] = v; return self
	func scatter(v: float) -> SpawnConfig:  _config["item_scatter"] = v; return self
	func param(k: String, v) -> SpawnConfig: _params[k] = v; return self
	
	func spawn() -> Enemy:
		if not _svc.active: return null
		return _svc._spawn(_key, _pos, _ctx, _config, _params)
