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
