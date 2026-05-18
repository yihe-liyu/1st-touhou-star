# BulletData.gd
extends Resource
class_name BulletData

enum Faction {PLAYER, ENEMY, BOMB}
enum HitboxShape {CIRCLE, RECTANGLE}

@export var texture: Texture2D ## 贴图
@export var damage: int = 10 ## 伤害
@export var velocity: Vector2 = Vector2.UP ## 速度
@export var hit_effect: PackedScene ## 击中时创建的特效场景

## 子弹阵营：自机/敌人/Bomb
@export var faction: Faction = Faction.PLAYER
## 是否可被 Bomb 消除（敌弹通常为 true）
@export var can_be_canceled: bool = false

# 判定区域
@export_group("Hitbox")
@export var hitbox_shape: HitboxShape = HitboxShape.CIRCLE ## 判定形状
@export var hitbox_offset: Vector2 = Vector2.ZERO ## 判定中心相对于子弹原点
@export var hitbox_radius: float = 4.0 ## [仅圆形]半径
@export var hitbox_size: Vector2 = Vector2(8, 8) ## [仅矩形]宽高
@export var hitbox_rotation: float = 0.0 ## [仅矩形]相对子弹朝向的额外旋转（度）

@export_group("", "")
@export var movement_script: Script ## 移动逻辑脚本。留空则默认直线飞行

var extra: Dictionary = {}
