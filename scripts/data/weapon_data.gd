# WeaponData.gd
extends Resource
class_name WeaponData

## 发射的子弹模板（BulletData）
@export var bullet_data: BulletData
## 射击间隔（秒）。0.08 = 每秒 ~12.5 发
@export var shoot_rate: float = 0.1
## 射击音效（可选）
@export var shoot_sound: AudioStream = null
## 子弹发射位置偏移（多个 = 多枪管）
@export var muzzle_positions: Array[Vector2] = [Vector2.ZERO]
