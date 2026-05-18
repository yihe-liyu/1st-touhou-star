# WeaponData.gd
extends Resource
class_name WeaponData

## 子弹 Data
@export var bullet_data: BulletData

## 射击间隔（秒）
@export var shoot_rate: float = 0.1

## 音效
@export var shoot_sound: AudioStream = null

## 子弹发射位置
@export var muzzle_positions: Array[Vector2] = [Vector2.ZERO]
