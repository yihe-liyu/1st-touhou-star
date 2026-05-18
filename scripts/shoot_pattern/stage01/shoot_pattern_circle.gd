# ShootPatternCircle.gd
extends ShootPattern
class_name ShootPatternCircle

## 发射的子弹配置
@export var bullet_data: BulletData

## 发射间隔（秒）
@export var interval: float = 0.01

## 每圈子弹数量
@export var bullet_count: int = 2

## 速度倍率（会覆盖 BulletData 里的速度）
@export var speed_multiplier: float = 1.0

var timer: float = 0.0

func update(delta: float):
	timer += delta
	if timer >= interval:
		timer -= interval
		# _shoot_circle()

func _shoot_circle():
	for i in range(bullet_count):
		var angle = TAU / bullet_count * i
		var dir = Vector2.RIGHT.rotated(angle)
		var data = _make_bullet_data()
		BulletManager.shoot_enemy_bullet(data, enemy.global_position, dir)

func _make_bullet_data() -> BulletData:
	var data = bullet_data.duplicate()
	data.velocity = data.velocity * speed_multiplier
	return data
