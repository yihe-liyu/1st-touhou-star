extends ShootPatternDef
class_name ShootArcDef

## 每轮发射子弹数量（最少 1）
@export var bullet_count: int = 3
## 扇形总开角（弧度）。1.57=90°半圆, 3.14=180°扇形
@export var arc_angle: float = 1.0
## true=扇形中心跟踪玩家方向, false=使用 fixed_direction
@export var aim_at_player: bool = true
## 固定方向（弧度），仅在 aim_at_player=false 时生效
@export var fixed_direction: float = 0.0
## 速度倍率（相对于 BulletData 中 velocity 长度）
@export var speed_multiplier: float = 1.0
