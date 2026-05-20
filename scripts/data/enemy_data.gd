# EnemyData.gd
extends Resource
class_name EnemyData

## 动画精灵帧（AnimatedSprite2D 用）
@export var sprite_frames: SpriteFrames
## 最大生命值
@export var max_hp: int = 100
## 受击判定半径（圆形）
@export var hitbox_radius: float = 8.0
## 击杀时获得的分数
@export var score_value: int = 100
## 死亡时生成的特效 PackedScene
@export var death_effect: PackedScene
## 弹幕模式配置数组。按顺序启动 Executor，支持并行
@export var shoot_pattern_defs: Array[ShootPatternDef] = []
## 移动模式脚本（EnemyMovement 子类）
@export var move_pattern: Script
