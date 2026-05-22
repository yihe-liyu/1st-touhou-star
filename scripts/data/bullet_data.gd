# BulletData.gd
extends Resource
class_name BulletData

enum Faction {PLAYER, ENEMY, BOMB}
enum HitboxShape {CIRCLE, RECTANGLE}

## 子弹贴图
@export var texture: Texture2D
## 基础伤害值
@export var damage: int = 10
## 速度向量（方向+速率，会被 speed_mult 缩放）
@export var velocity: Vector2 = Vector2.UP
## 击中时创建的特效 PackedScene
@export var hit_effect: PackedScene
## 子弹阵营：自机(0) / 敌人(1) / Bomb(2)
@export var faction: Faction = Faction.PLAYER
## 是否可被 Bomb 消除（敌弹通常为 true）
@export var can_be_canceled: bool = false

@export_group("Hitbox")
## 判定形状：圆形 / 矩形
@export var hitbox_shape: HitboxShape = HitboxShape.CIRCLE
## 判定中心相对于子弹原点的偏移
@export var hitbox_offset: Vector2 = Vector2.ZERO
## [仅圆形] 判定半径
@export var hitbox_radius: float = 4.0
## [仅矩形] 判定宽高
@export var hitbox_size: Vector2 = Vector2(8, 8)
## [仅矩形] 相对子弹朝向的额外旋转（弧度）
@export var hitbox_rotation: float = 0.0

@export_group("", "")
## 移动逻辑脚本。留空则默认直线飞行 (MoveLinear)
@export var movement_script: Script
