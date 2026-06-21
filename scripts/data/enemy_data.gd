# EnemyData.gd
## 敌人配置：外观、血量、判定、掉落、弹幕/移动脚本
extends Resource
class_name EnemyData

@export var visual_scene: PackedScene       ## 外观场景
@export var max_hp: int = 100               ## 最大生命
@export var hitbox_radius: float = 8.0      ## 判定半径（像素）
@export var score_value: int = 100          ## 击破分数
@export var death_effect: PackedScene       ## 死亡特效
@export var create_script: Script           ## 弹幕脚本
@export var move_script: Script             ## 移动脚本
@export var boss_data: BossData             ## Boss 数据（非空=此敌是 Boss）

@export_group("Item", "item_")
@export var item_power: int = 0
@export var item_point: int = 0
@export var item_life: int = 0
@export var item_bomb: int = 0
@export var item_life_full: int = 0
@export var item_bomb_full: int = 0
@export var item_scatter: float = 50.0      ## 生成位置随机散布（像素）
