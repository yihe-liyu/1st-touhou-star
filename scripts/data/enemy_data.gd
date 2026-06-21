## 敌人配置：外观、血量、判定、掉落（构造链）
extends Resource
class_name EnemyData

var visual_scene: PackedScene   ## 外观场景
var max_hp: int = 100           ## 最大生命
var hitbox_radius: float = 8.0  ## 判定半径（像素）
var score_value: int = 100      ## 击破分数
var death_effect: PackedScene = preload("res://data/enemy_visual/death_effect.tscn")  ## 死亡特效
var boss_data: BossData         ## Boss 数据

var item_power: int = 0         ## 掉落P道具数
var item_point: int = 0         ## 掉落点道具数
var item_life: int = 0          ## 掉落命碎片数
var item_bomb: int = 0          ## 掉落雷碎片数
var item_life_full: int = 0     ## 掉落整命数
var item_bomb_full: int = 0     ## 掉落整雷数
var item_scatter: float = 50.0  ## 掉落散布范围（像素）

## ── 构造链 ──

const _ENEMY_SCENE = preload("res://scenes/enemy.tscn")

var _spawn_meta: Dictionary = {}

func hp(v: int) -> EnemyData:         max_hp = v; return self
func hbox(v: float) -> EnemyData:     hitbox_radius = v; return self
func score(v: int) -> EnemyData:      score_value = v; return self
func power(v: int) -> EnemyData:      item_power = v; return self
func point(v: int) -> EnemyData:      item_point = v; return self
func life(v: int) -> EnemyData:       item_life = v; return self
func bomb(v: int) -> EnemyData:       item_bomb = v; return self
func life_full(v: int) -> EnemyData:  item_life_full = v; return self
func bomb_full(v: int) -> EnemyData:  item_bomb_full = v; return self
func scatter(v: float) -> EnemyData:  item_scatter = v; return self
func param(k: String, v) -> EnemyData:
	if not _spawn_meta.has("params"):
		_spawn_meta["params"] = {}
	_spawn_meta["params"][k] = v
	return self

func spawn() -> Enemy:
	var svc: EnemyService = _spawn_meta.get("svc")
	if not svc or not svc.active:
		return null
	var key: String = _spawn_meta.get("key", "")
	var pos: Vector2 = _spawn_meta.get("pos", Vector2.ZERO)
	var params: Dictionary = _spawn_meta.get("params", {})
	
	var script: Script = EnemyService.SCRIPTS.get(key)
	if not script: return null
	
	var enemy := _ENEMY_SCENE.instantiate()
	enemy.global_position = pos
	enemy.enemy_data = self
	
	var cs: CoroutineScript = script.new()
	if not cs:
		push_warning("EnemyData.spawn(): %s is not a CoroutineScript" % key)
		enemy.queue_free()
		return null
	
	cs.target = enemy
	for k in params:
		cs.set(k, params[k])
	if cs.has_method("setup_custom"):
		cs.setup_custom(params)
	enemy.add_child(cs)
	cs.start(svc.ctx, enemy)
	
	StageManager.add_enemy_to_scene(enemy)
	return enemy
