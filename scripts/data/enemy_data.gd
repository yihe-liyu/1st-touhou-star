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

var _script: Script
var _pos: Vector2 = Vector2.ZERO
var _params: Dictionary = {}

func script(s: Script) -> EnemyData:   _script = s; return self
func pos(p: Vector2) -> EnemyData:     _pos = p; return self
func hp(v: int) -> EnemyData:          max_hp = v; return self
func hbox(v: float) -> EnemyData:      hitbox_radius = v; return self
func score(v: int) -> EnemyData:       score_value = v; return self
func power(v: int) -> EnemyData:       item_power = v; return self
func point(v: int) -> EnemyData:       item_point = v; return self
func life(v: int) -> EnemyData:        item_life = v; return self
func bomb(v: int) -> EnemyData:        item_bomb = v; return self
func life_full(v: int) -> EnemyData:   item_life_full = v; return self
func bomb_full(v: int) -> EnemyData:   item_bomb_full = v; return self
func scatter(v: float) -> EnemyData:   item_scatter = v; return self
func param(k: String, v) -> EnemyData: _params[k] = v; return self
func visual(key: String) -> EnemyData:
	visual_scene = AssetRegistry.enemy_visuals.get(key, preload("res://data/enemy_visual/red_little_fairy.tscn"))
	return self

## 生成敌人 —— 数据类不持有场景，实例化/挂载委托给 StageManager
func spawn(p_ctx: StageContext = null) -> Enemy:
	return StageManager.spawn_enemy_data(self, p_ctx)

## ── 生成参数（供 StageManager 读取） ──

func has_script() -> bool:            return _script != null
func get_enemy_script() -> Script:    return _script
func get_spawn_pos() -> Vector2:      return _pos
func get_params() -> Dictionary:      return _params
func make_script() -> CoroutineScript:
	if _script:
		return _script.new()
	return null

## ── 构造链模板 ──

func red_little_fairy() -> EnemyData:
	self.visual("red_little_fairy").hbox(25).hp(45).power(2)
	return self

func blue_little_fairy() -> EnemyData:
	self.visual("blue_little_fairy").hbox(25).hp(45).point(2)
	return self

func green_little_fairy() -> EnemyData:
	self.visual("green_little_fairy").hbox(25).hp(45).power(1).point(1)
	return self

func yellow_little_fairy() -> EnemyData:
	self.visual("yellow_little_fairy").hbox(25).hp(45).power(1).point(1)
	return self

func red_middle_fairy() -> EnemyData:
	self.visual("red_middle_fairy").hbox(35).hp(200).power(7).point(2)
	return self

func blue_middle_fairy() -> EnemyData:
	self.visual("blue_middle_fairy").hbox(35).hp(200).power(2).point(7)
	return self

func red_big_fairy() -> EnemyData:
	self.visual("red_big_fairy").hbox(48).hp(400).power(12).point(5)
	return self

func blue_big_fairy() -> EnemyData:
	self.visual("blue_big_fairy").hbox(48).hp(400).power(5).point(12)
	return self

func white_huge_fairy() -> EnemyData:
	self.visual("white_huge_fairy").hbox(56).hp(900).power(20).point(20)
	return self

func red_YY_jade() -> EnemyData:
	self.visual("red_YY_jade").hbox(40).hp(150).power(5)
	return self

func green_YY_jade() -> EnemyData:
	self.visual("green_YY_jade").hbox(40).hp(150).power(2).point(3)
	return self

func blue_YY_jade() -> EnemyData:
	self.visual("blue_YY_jade").hbox(40).hp(150).point(5)
	return self

func purple_YY_jade() -> EnemyData:
	self.visual("purple_YY_jade").hbox(40).hp(150).power(3).point(2)
	return self
