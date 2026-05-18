# ShootPatternCircle.gd
extends ShootPattern
class_name ShootPatternCircle

@export var bullet_data: BulletData

@export var interval: float = 0.01

@export var bullet_count: int = 2

@export var speed_multiplier: float = 1.0

var _override: BulletOverride
var timer: float = 0.0

func bind(e: Enemy):
	super.bind(e)
	_override = BulletOverride.new()
	_override.speed_mult = speed_multiplier

func update(delta: float):
	timer += delta
	if timer >= interval:
		timer -= interval
		_shoot_circle()

func _shoot_circle():
	for i in range(bullet_count):
		var angle = TAU / bullet_count * i
		var dir = Vector2.RIGHT.rotated(angle)
		BulletManager.shoot_enemy_bullet(bullet_data, enemy.global_position, dir, _override)
