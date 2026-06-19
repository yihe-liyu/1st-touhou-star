# EnemyData.gd
extends Resource
class_name EnemyData

## 敌人外观场景（支持任意节点组合，AnimatedSprite2D / Sprite2D / 多节点旋转等）
@export var visual_scene: PackedScene
@export var max_hp: int = 100
@export var hitbox_radius: float = 8.0
@export var score_value: int = 100
@export var death_effect: PackedScene
@export var create_script: Script
@export var move_script: Script
@export var boss_data: BossData   ## Boss 数据（非空=此敌是 Boss）

@export_group("Item", "item_")
@export var item_power: int = 0
@export var item_point: int = 0
@export var item_life: int = 0
@export var item_bomb: int = 0
@export var item_life_full: int = 0
@export var item_bomb_full: int = 0
@export var item_scatter: float = 50.0          ## 生成位置随机散布(像素)
