extends ShootPatternDef
class_name ShootCircleDef

## 每轮子弹数量（等角分布成圆）
@export var bullet_count: int = 2
## 速度倍率（相对于 BulletData 中 velocity 长度）
@export var speed_multiplier: float = 1.0
## 初始偏移角度（弧度），可让圆形旋转
@export var offset_angle: float = 0.0
