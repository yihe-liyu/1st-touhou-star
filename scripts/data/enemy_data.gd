## 敌人配置：外观、血量、判定、掉落
extends Resource
class_name EnemyData

var visual_scene: PackedScene   ## 外观场景
var max_hp: int = 100           ## 最大生命
var hitbox_radius: float = 8.0  ## 判定半径（像素）
var score_value: int = 100      ## 击破分数
var death_effect: PackedScene   ## 死亡特效
var boss_data: BossData         ## Boss 数据

var item_power: int = 0         ## 掉落P道具数
var item_point: int = 0         ## 掉落点道具数
var item_life: int = 0          ## 掉落命碎片数
var item_bomb: int = 0          ## 掉落雷碎片数
var item_life_full: int = 0     ## 掉落整命数
var item_bomb_full: int = 0     ## 掉落整雷数
var item_scatter: float = 50.0  ## 掉落散布范围（像素）
