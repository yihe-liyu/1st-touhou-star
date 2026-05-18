extends ShootPatternDef
class_name ShootAimedDef

## 每轮发射子弹数量（1=单发直狙）
@export var bullet_count: int = 1
## 扩散角度（弧度）。0=精准瞄准，>0=多弹时各弹之间的总扩散角
@export var spread_angle: float = 0.0
## 速度倍率（相对于 BulletData 中 velocity 长度）
@export var speed_multiplier: float = 1.0
## 瞄准偏移角度（弧度）。正值=顺时针偏移瞄准方向
@export var aim_offset: float = 0.0
