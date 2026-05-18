# EnemyData.gd
extends Resource
class_name EnemyData

## 动画
@export var sprite_frames: SpriteFrames

## 最大生命值
@export var max_hp: int = 100

## 受击判定半径（圆形）
@export var hitbox_radius: float = 8.0

## 击杀得分
@export var score_value: int = 100

## 死亡时生成的特效
@export var death_effect: PackedScene

## 发弹脚本
@export var shoot_pattern: ShootPattern
