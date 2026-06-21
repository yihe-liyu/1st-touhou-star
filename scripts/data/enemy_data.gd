## 敌人配置：外观、血量、判定、掉落
extends Resource
class_name EnemyData

var visual_scene: PackedScene
var max_hp: int = 100
var hitbox_radius: float = 8.0
var score_value: int = 100
var death_effect: PackedScene
var boss_data: BossData

var item_power: int = 0
var item_point: int = 0
var item_life: int = 0
var item_bomb: int = 0
var item_life_full: int = 0
var item_bomb_full: int = 0
var item_scatter: float = 50.0
